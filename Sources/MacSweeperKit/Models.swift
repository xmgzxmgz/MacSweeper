import Foundation

public struct FileItem: Hashable, Sendable {
    public let url: URL
    public let size: Int64
    public let lastAccessDate: Date?
    public let isDirectory: Bool
    public let isUbiquitousItem: Bool?
    public let isUbiquitousItemDownloaded: Bool?
    public let isOnExternalVolume: Bool?

    public init(
        url: URL,
        size: Int64,
        lastAccessDate: Date?,
        isDirectory: Bool,
        isUbiquitousItem: Bool? = nil,
        isUbiquitousItemDownloaded: Bool? = nil,
        isOnExternalVolume: Bool? = nil
    ) {
        self.url = url
        self.size = size
        self.lastAccessDate = lastAccessDate
        self.isDirectory = isDirectory
        self.isUbiquitousItem = isUbiquitousItem
        self.isUbiquitousItemDownloaded = isUbiquitousItemDownloaded
        self.isOnExternalVolume = isOnExternalVolume
    }
}

public enum SuggestionKind: String, Sendable, Hashable, CaseIterable {
    case large
    case old
    case duplicate
    case cacheLog
    case cloudPlaceholder
}

public struct DeletionCandidate: Hashable, Sendable {
    public let fileItem: FileItem
    public let reason: String
    public let kind: SuggestionKind?
    public var isMarkedForDeletion: Bool
    public let riskLevel: RiskLevel?
    public let contentHash: String?

    public init(
        fileItem: FileItem,
        reason: String,
        kind: SuggestionKind? = nil,
        isMarkedForDeletion: Bool = false,
        riskLevel: RiskLevel? = nil,
        contentHash: String? = nil
    ) {
        self.fileItem = fileItem
        self.reason = reason
        self.kind = kind
        self.isMarkedForDeletion = isMarkedForDeletion
        self.riskLevel = riskLevel
        self.contentHash = contentHash
    }
}

public struct AnalysisSummary: Sendable {
    public let totalFilesScanned: Int
    public let totalSizeCleanable: Int64
    public let duplicateCount: Int
    public let largeFilesCount: Int
    public let oldFilesCount: Int
    public let cacheLogCount: Int
    public let cloudPlaceholderCount: Int

    public init(totalFilesScanned: Int, totalSizeCleanable: Int64, duplicateCount: Int, largeFilesCount: Int, oldFilesCount: Int, cacheLogCount: Int, cloudPlaceholderCount: Int = 0) {
        self.totalFilesScanned = totalFilesScanned
        self.totalSizeCleanable = totalSizeCleanable
        self.duplicateCount = duplicateCount
        self.largeFilesCount = largeFilesCount
        self.oldFilesCount = oldFilesCount
        self.cacheLogCount = cacheLogCount
        self.cloudPlaceholderCount = cloudPlaceholderCount
    }
}

public enum RiskLevel: Int, Sendable, Hashable {
    case low = 0     // 缓存/日志、重复的非保留项
    case medium = 1  // 旧文件
    case high = 2    // 大文件、云占位（谨慎）
}