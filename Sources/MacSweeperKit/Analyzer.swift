import Foundation

public final class Analyzer {
    private let hashService: HashService

    public init(hashService: HashService = HashService()) {
        self.hashService = hashService
    }

    /// 规则 1：大文件（默认 > 1GB）
    public func identifyLargeFiles(items: [FileItem], thresholdBytes: Int64 = 1_000_000_000) -> [DeletionCandidate] {
        items.filter { $0.size >= thresholdBytes }.map {
            DeletionCandidate(fileItem: $0, reason: "大文件（≥\(formatBytes(thresholdBytes))）", kind: .large, isMarkedForDeletion: false, riskLevel: .high)
        }
    }

    /// 规则 2：旧文件（默认 365 天未访问）
    public func identifyOldFiles(items: [FileItem], olderThanDays: Int = 365) -> [DeletionCandidate] {
        let cutoff = Date().addingTimeInterval(Double(-olderThanDays) * 24 * 3600)
        return items.compactMap { item in
            guard let access = item.lastAccessDate else { return nil }
            return access < cutoff ? DeletionCandidate(fileItem: item, reason: "长时间未访问（≥\(olderThanDays)天）", kind: .old) : nil
        }
    }

    /// 规则 3：重复文件（按大小+哈希，支持并发与快速采样）
    public func identifyDuplicates(items: [FileItem], concurrency: Int = 4, useFastHash: Bool = true) -> [DeletionCandidate] {
        // 先按大小分组，减少哈希计算
        let groups = Dictionary(grouping: items.filter { !$0.isDirectory }) { $0.size }
        var duplicates: [DeletionCandidate] = []

        for (_, group) in groups where group.count > 1 {
            let urls = group.map { $0.url }
            let hashes = hashService.computeHashes(urls: urls, concurrency: concurrency, useFastHash: useFastHash)
            var hashMap: [String: [FileItem]] = [:]
            for item in group {
                if let h = hashes[item.url] {
                    hashMap[h, default: []].append(item)
                }
            }
            for (hash, dupGroup) in hashMap where dupGroup.count > 1 {
                // 保留一个，其余建议删除
                let toSuggest = dupGroup.dropFirst()
                duplicates.append(contentsOf: toSuggest.map {
                    DeletionCandidate(fileItem: $0, reason: "重复文件（内容一致）", kind: .duplicate, isMarkedForDeletion: false, riskLevel: .low, contentHash: hash)
                })
            }
        }

        return duplicates
    }

    /// 规则 4：缓存与日志目录（简单路径匹配）
    public func identifyCacheAndLogs(items: [FileItem]) -> [DeletionCandidate] {
        let patterns = ["/Library/Caches", "/Library/Logs"]
        return items.compactMap { item in
            let path = item.url.path
            if patterns.contains(where: { path.contains($0) }) {
                return DeletionCandidate(fileItem: item, reason: "缓存/日志目录中的文件", kind: .cacheLog, isMarkedForDeletion: false, riskLevel: .low)
            }
            return nil
        }
    }

    /// 规则 5：云占位文件（iCloud/Dropbox 未下载的泛在项）
    public func identifyCloudPlaceholders(items: [FileItem]) -> [DeletionCandidate] {
        items.compactMap { item in
            if item.isUbiquitousItem == true && item.isUbiquitousItemDownloaded == false {
                return DeletionCandidate(fileItem: item, reason: "云占位文件（未下载，谨慎删除）", kind: .cloudPlaceholder, isMarkedForDeletion: false, riskLevel: .high)
            }
            return nil
        }
    }

    public func summarize(candidates: [DeletionCandidate], totalScanned: Int) -> AnalysisSummary {
        let totalCleanable = candidates.reduce(Int64(0)) { $0 + $1.fileItem.size }
        let duplicateCount = candidates.filter { $0.kind == .duplicate }.count
        let largeFilesCount = candidates.filter { $0.kind == .large }.count
        let oldFilesCount = candidates.filter { $0.kind == .old }.count
        let cacheLogCount = candidates.filter { $0.kind == .cacheLog }.count
        let cloudPlaceholderCount = candidates.filter { $0.kind == .cloudPlaceholder }.count
        return AnalysisSummary(totalFilesScanned: totalScanned, totalSizeCleanable: totalCleanable, duplicateCount: duplicateCount, largeFilesCount: largeFilesCount, oldFilesCount: oldFilesCount, cacheLogCount: cacheLogCount, cloudPlaceholderCount: cloudPlaceholderCount)
    }

    /// 路径保护与外接盘风险提升：系统目录与外接卷默认提高风险
    public func applyProtections(candidates: [DeletionCandidate]) -> [DeletionCandidate] {
        let protectedPrefixes = ["/System", "/usr", "/bin", "/sbin", "/Library"]
        return candidates.map { cand in
            let path = cand.fileItem.url.path
            let onExternal = cand.fileItem.isOnExternalVolume == true
            let inProtected = protectedPrefixes.contains { path.hasPrefix($0) } && !path.hasPrefix(NSHomeDirectory() + "/Library")
            let newRisk: RiskLevel? = (onExternal || inProtected) ? .high : cand.riskLevel
            return DeletionCandidate(fileItem: cand.fileItem, reason: cand.reason, kind: cand.kind, isMarkedForDeletion: cand.isMarkedForDeletion, riskLevel: newRisk, contentHash: cand.contentHash)
        }
    }

    // formatBytes is defined in Utilities.swift
}