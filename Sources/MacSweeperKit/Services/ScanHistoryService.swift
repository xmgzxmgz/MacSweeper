import Foundation

public struct ScanHistoryEntry: Codable, Sendable {
    public let date: Date
    public let totalFilesScanned: Int
    public let totalSizeCleanable: Int64
    public let duplicateCount: Int
    public let largeFilesCount: Int
    public let oldFilesCount: Int
    public let cacheLogCount: Int
    public let cloudPlaceholderCount: Int
    public let scanDurationSeconds: Double
    public let duplicateAnalysisSeconds: Double
}

public final class ScanHistoryService {
    private let fm = FileManager.default
    private let historyURL: URL

    public init() {
        let support = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/MacSweeper")
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        historyURL = support.appendingPathComponent("scan_history.json")
    }

    private static let maxEntries = 50

    public func append(_ entry: ScanHistoryEntry) {
        var list = load()
        list.append(entry)
        // 保留最近 N 条记录，避免历史文件无限增长
        if list.count > Self.maxEntries {
            list = Array(list.suffix(Self.maxEntries))
        }
        save(list)
    }

    public func load() -> [ScanHistoryEntry] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        return (try? JSONDecoder().decode([ScanHistoryEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [ScanHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: historyURL)
    }
}