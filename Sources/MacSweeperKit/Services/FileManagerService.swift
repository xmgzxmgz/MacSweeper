import Foundation

public final class FileManagerService {
    private let fm = FileManager.default

    public init() {}

    /// 请求目录访问权限（CLI 环境下直接返回 true；GUI 环境需用 NSOpenPanel/权限沙盒）
    public func requestAccess(to url: URL) -> Bool {
        return true
    }

    /// 递归扫描目录，返回 FileItem 列表（为简化 CLI，同步返回）
    public func scanDirectory(at url: URL) -> [FileItem] {
        var items: [FileItem] = []
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .contentAccessDateKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .volumeIsRemovableKey,
            .volumeURLKey
        ]

        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles], errorHandler: { (errorURL, error) -> Bool in
            // 跳过无法访问的路径
            return true
        }) else {
            return items
        }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                let isDir = values.isDirectory ?? false
                let isFile = values.isRegularFile ?? false
                let size = (values.totalFileAllocatedSize ?? values.fileSize).map { Int64($0) } ?? 0
                let accessDate = values.contentAccessDate
                let isUbiquitous = values.isUbiquitousItem ?? false
                // ubiquitousItemDownloadingStatus == .current means already downloaded
                let isDownloaded: Bool = {
                    guard let status = values.ubiquitousItemDownloadingStatus else { return true }
                    return status != .notDownloaded
                }()
                // Use volumeIsRemovable as a proxy for external volumes (volumeIsExternal requires macOS 13+)
                let isExternal = values.volumeIsRemovable ?? false

                // 仅记录文件（不记录目录）
                if isFile {
                    items.append(FileItem(
                        url: fileURL,
                        size: size,
                        lastAccessDate: accessDate,
                        isDirectory: isDir,
                        isUbiquitousItem: isUbiquitous,
                        isUbiquitousItemDownloaded: isDownloaded,
                        isOnExternalVolume: isExternal
                    ))
                }
            } catch {
                // 忽略单个文件的错误，继续扫描
                continue
            }
        }
        return items
    }

    /// 安全删除：移动到废纸篓
    @discardableResult
    public func safeDelete(fileItem: FileItem) -> Bool {
        var resultingURL: NSURL?
        do {
            try fm.trashItem(at: fileItem.url, resultingItemURL: &resultingURL)
            return true
        } catch {
            Logger.shared.log(.error, "删除失败: \(fileItem.url.path) - \(error.localizedDescription)")
            return false
        }
    }
}
