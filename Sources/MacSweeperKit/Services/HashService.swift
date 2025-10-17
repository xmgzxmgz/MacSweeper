import Foundation
import CryptoKit

public final class HashService {
    private var cache: [String: String] = [:]
    private let cacheURL: URL

    public init() {
        let support = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/MacSweeper")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.cacheURL = support.appendingPathComponent("hash_cache.json")
        loadCache()
    }

    /// 计算完整文件的 SHA256
    public func calculateSHA256(for url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024) // 1MB 分块
            if let data, !data.isEmpty {
                hasher.update(data: data)
                return true
            }
            return false
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 计算快速采样哈希：取文件头尾各 1MB，拼接后做 SHA256（用于预分组）
    public func calculateSampleSHA256(for url: URL, sampleSize: Int = 1024 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        var hasher = SHA256()

        // 头部
        if let head = try? handle.read(upToCount: sampleSize), let head, !head.isEmpty {
            hasher.update(data: head)
        }
        // 尾部
        if size > Int64(sampleSize) {
            do {
                try handle.seek(toOffset: UInt64(max(0, size - Int64(sampleSize))))
                if let tail = try? handle.read(upToCount: sampleSize), let tail, !tail.isEmpty {
                    hasher.update(data: tail)
                }
            } catch {
                // 忽略尾部读取失败
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 获取缓存键：path + size + mtime
    private func cacheKey(for url: URL) -> String {
        let fm = FileManager.default
        let attrs = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(size)|\(Int(mtime))"
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            cache = obj
        }
    }

    private func saveCache() {
        guard let data = try? JSONSerialization.data(withJSONObject: cache, options: [.prettyPrinted]) else { return }
        try? data.write(to: cacheURL)
    }

    /// 获取内容哈希（有缓存则命中），可选择快速采样作为预判
    public func contentHash(for url: URL, useFastHash: Bool) -> String? {
        let key = cacheKey(for: url)
        if let cached = cache[key] { return cached }
        let hash = useFastHash ? (calculateSampleSHA256(for: url) ?? calculateSHA256(for: url)) : calculateSHA256(for: url)
        if let hash { cache[key] = hash; saveCache() }
        return hash
    }

    /// 并发计算多个文件哈希，限制并发度
    public func computeHashes(urls: [URL], concurrency: Int = 4, useFastHash: Bool = true) -> [URL: String] {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = max(1, concurrency)
        var result: [URL: String] = [:]
        let lock = NSLock()
        let ops = urls.map { url -> BlockOperation in
            BlockOperation { [weak self] in
                guard let self else { return }
                if let h = self.contentHash(for: url, useFastHash: useFastHash) {
                    lock.lock(); result[url] = h; lock.unlock()
                }
            }
        }
        queue.addOperations(ops, waitUntilFinished: true)
        return result
    }
}