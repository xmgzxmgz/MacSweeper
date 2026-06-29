import Foundation
import Combine

/// 预留给 SwiftUI 应用使用的 ViewModel（CLI 不直接用）
public final class MainViewModel: ObservableObject {
    @Published public var scanProgress: Double = 0
    @Published public var currentStatus: String = ""
    @Published public var isScanning: Bool = false
    @Published public var analysisSummary: AnalysisSummary = .init(totalFilesScanned: 0, totalSizeCleanable: 0, duplicateCount: 0, largeFilesCount: 0, oldFilesCount: 0, cacheLogCount: 0, cloudPlaceholderCount: 0)
    @Published public var deletionCandidates: [DeletionCandidate] = []
    @Published public var filteredCandidates: [DeletionCandidate] = []

    @Published public var settings: UserSettings = .init()
    @Published public var filters: FilterOptions = .init()
    @Published public var isCancelled: Bool = false
    @Published public var lastDeletedOriginalPaths: [URL] = []

    private let fmService = FileManagerService()
    private let analyzer = Analyzer()
    private let historyService = ScanHistoryService()
    private var lastScanStart: Date = .distantPast
    private var lastDuplicateStart: Date = .distantPast

    public init() {}

    public func startAnalysis(paths: [URL], largeThresholdBytes: Int64? = nil, oldDays: Int? = nil, includeDuplicates: Bool? = nil) {
        isScanning = true
        currentStatus = "开始扫描..."
        deletionCandidates.removeAll()
        filteredCandidates.removeAll()
        isCancelled = false
        Logger.shared.setEnabled(settings.enableLogging)
        Logger.shared.log(.info, "开始扫描：\(paths.map{ $0.path }.joined(separator: ", "))")
        lastScanStart = Date()

        var allItems: [FileItem] = []
        for (idx, url) in paths.enumerated() {
            currentStatus = "扫描：\(url.path)"
            if isCancelled { break }
            let items = fmService.scanDirectory(at: url)
            allItems.append(contentsOf: items)
            scanProgress = Double(idx + 1) / Double(paths.count)
        }

        var candidates: [DeletionCandidate] = []
        let thBytes = largeThresholdBytes ?? settings.largeThresholdBytes
        let days = oldDays ?? settings.oldDays
        let dup = includeDuplicates ?? settings.includeDuplicates

        // 预过滤：排除路径与扩展名
        let prefiltered = allItems.filter { item in
            let path = item.url.path
            if settings.excludePaths.contains(where: { path.hasPrefix($0) }) { return false }
            if let ext = item.url.pathExtension.lowercased(), !ext.isEmpty {
                if settings.excludeExtensions.contains(ext) { return false }
            }
            return true
        }

        candidates += analyzer.identifyLargeFiles(items: prefiltered, thresholdBytes: thBytes)
        candidates += analyzer.identifyOldFiles(items: prefiltered, olderThanDays: days)
        if dup {
            lastDuplicateStart = Date()
            candidates += analyzer.identifyDuplicates(items: prefiltered, concurrency: settings.hashConcurrency, useFastHash: settings.useFastHash)
        }
        candidates += analyzer.identifyCacheAndLogs(items: prefiltered)
        candidates += analyzer.identifyCloudPlaceholders(items: prefiltered)
        candidates = analyzer.applyProtections(candidates: candidates)

        deletionCandidates = candidates
        analysisSummary = analyzer.summarize(candidates: candidates, totalScanned: allItems.count)
        applyFiltersAndSort()
        let scanDuration = Date().timeIntervalSince(lastScanStart)
        let dupDuration = dup ? Date().timeIntervalSince(lastDuplicateStart) : 0
        historyService.append(.init(date: Date(), totalFilesScanned: allItems.count, totalSizeCleanable: analysisSummary.totalSizeCleanable, duplicateCount: analysisSummary.duplicateCount, largeFilesCount: analysisSummary.largeFilesCount, oldFilesCount: analysisSummary.oldFilesCount, cacheLogCount: analysisSummary.cacheLogCount, cloudPlaceholderCount: analysisSummary.cloudPlaceholderCount, scanDurationSeconds: scanDuration, duplicateAnalysisSeconds: dupDuration))
        Logger.shared.log(.info, "扫描完成，耗时：\(String(format: "%.2f", scanDuration))s；查重耗时：\(String(format: "%.2f", dupDuration))s")
        currentStatus = "扫描完成"
        isScanning = false
        scanProgress = 1
    }

    public func applyFiltersAndSort() {
        var items = deletionCandidates
        // 过滤类别
        items = items.filter { cand in
            guard let k = cand.kind else { return true }
            return filters.kinds.contains(k)
        }
        // 过滤大小
        if let min = filters.minSizeBytes { items = items.filter { $0.fileItem.size >= min } }
        if let max = filters.maxSizeBytes { items = items.filter { $0.fileItem.size <= max } }
        // 搜索
        let text = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !text.isEmpty {
            items = items.filter { cand in
                cand.fileItem.url.path.lowercased().contains(text) || cand.reason.lowercased().contains(text)
            }
        }
        // 正则过滤
        if let pattern = filters.regexPattern, !pattern.isEmpty {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                items = items.filter { cand in
                    let path = cand.fileItem.url.path
                    let range = NSRange(location: 0, length: path.utf16.count)
                    return regex.firstMatch(in: path, options: [], range: range) != nil
                }
            }
        }
        // 通配符过滤（* ? 简单转换为正则）
        if let wildcard = filters.wildcardPattern, !wildcard.isEmpty {
            let escaped = NSRegularExpression.escapedPattern(for: wildcard)
            let regexPattern = escaped.replacingOccurrences(of: "\\*", with: ".*").replacingOccurrences(of: "\\?", with: ".")
            if let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$", options: [.caseInsensitive]) {
                items = items.filter { cand in
                    let path = cand.fileItem.url.lastPathComponent
                    let range = NSRange(location: 0, length: path.utf16.count)
                    return regex.firstMatch(in: path, options: [], range: range) != nil
                }
            }
        }
        // 排序
        switch settings.sortMode {
        case .bySize:
            items.sort { $0.fileItem.size > $1.fileItem.size }
        case .byLowRisk:
            let score: (DeletionCandidate) -> Int = { cand in
                if let r = cand.riskLevel { return r.rawValue }
                // 回退：按类别推断
                switch cand.kind {
                case .cacheLog?: return RiskLevel.low.rawValue
                case .duplicate?: return RiskLevel.low.rawValue
                case .old?: return RiskLevel.medium.rawValue
                case .large?: return RiskLevel.high.rawValue
                case .cloudPlaceholder?: return RiskLevel.high.rawValue
                default: return RiskLevel.medium.rawValue
                }
            }
            items.sort { score($0) < score($1) }
        case .byOldest:
            items.sort { ($0.fileItem.lastAccessDate ?? .distantPast) < ($1.fileItem.lastAccessDate ?? .distantPast) }
        }
        filteredCandidates = items
    }

    public func selectAllFiltered(_ checked: Bool) {
        for idx in deletionCandidates.indices {
            let cand = deletionCandidates[idx]
            if filteredCandidates.contains(cand) {
                deletionCandidates[idx].isMarkedForDeletion = checked
            }
        }
        applyFiltersAndSort()
    }

    public func processSelectedDeletions() {
        let selected = deletionCandidates.filter { $0.isMarkedForDeletion }
        lastDeletedOriginalPaths = selected.map { $0.fileItem.url }
        guard !settings.dryRun else { return }
        for candidate in selected {
            _ = fmService.safeDelete(fileItem: candidate.fileItem)
        }
        // 更新摘要与过滤视图
        analysisSummary = analyzer.summarize(candidates: deletionCandidates.filter { !$0.isMarkedForDeletion }, totalScanned: analysisSummary.totalFilesScanned)
        applyFiltersAndSort()
    }

    /// 重复文件自动保留策略：按 contentHash 分组，每组保留一个，其余打勾删除
    public func applyDuplicateRetainPolicy() {
        let policy = settings.duplicateRetainPolicy
        let dups = deletionCandidates.filter { $0.kind == .duplicate }
        let groups = Dictionary(grouping: dups, by: { $0.contentHash ?? "size:\($0.fileItem.size)" })
        for (_, group) in groups {
            guard !group.isEmpty else { continue }
            // 选择保留项
            let keep: DeletionCandidate?
            switch policy {
            case .keepNewest:
                keep = group.max(by: { ($0.fileItem.lastAccessDate ?? .distantPast) < ($1.fileItem.lastAccessDate ?? .distantPast) })
            case .keepOldest:
                keep = group.min(by: { ($0.fileItem.lastAccessDate ?? .distantFuture) < ($1.fileItem.lastAccessDate ?? .distantFuture) })
            case .keepShortestPath:
                keep = group.min(by: { $0.fileItem.url.path.count < $1.fileItem.url.path.count })
            }
            // 其余标记为删除
            for idx in deletionCandidates.indices {
                let cand = deletionCandidates[idx]
                if group.contains(cand) {
                    deletionCandidates[idx].isMarkedForDeletion = (cand != keep)
                }
            }
        }
        applyFiltersAndSort()
    }

    public func resetState() {
        scanProgress = 0
        currentStatus = ""
        isScanning = false
        analysisSummary = .init(totalFilesScanned: 0, totalSizeCleanable: 0, duplicateCount: 0, largeFilesCount: 0, oldFilesCount: 0, cacheLogCount: 0, cloudPlaceholderCount: 0)
        deletionCandidates.removeAll()
        filteredCandidates.removeAll()
    }

    public func cancelScan() { isCancelled = true }

    public func applyPreset(_ preset: ScanPreset) {
        settings.preset = preset
        switch preset {
        case .light:
            settings.largeThresholdBytes = 2_000_000_000 // 2GB
            settings.oldDays = 365
            settings.includeDuplicates = false
        case .standard:
            settings.largeThresholdBytes = 1_000_000_000 // 1GB
            settings.oldDays = 365
            settings.includeDuplicates = true
        case .deep:
            settings.largeThresholdBytes = 500_000_000 // 500MB
            settings.oldDays = 180
            settings.includeDuplicates = true
        }
    }

    public var quickScanDefaultPaths: [URL] {
        [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches")
        ]
    }

    public func exportJSON(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(filteredCandidates.map { [
            "path": $0.fileItem.url.path,
            "size": "\($0.fileItem.size)",
            "reason": $0.reason,
            "kind": $0.kind?.rawValue ?? ""
        ] })
        try data.write(to: url)
    }

    public func exportCSV(to url: URL) throws {
        let header = "path,size,reason,kind\n"
        let rows = filteredCandidates.map { cand in
            let path = cand.fileItem.url.path.replacingOccurrences(of: ",", with: " ")
            return "\(path),\(cand.fileItem.size),\(cand.reason),\(cand.kind?.rawValue ?? "")"
        }.joined(separator: "\n")
        let data = (header + rows).data(using: .utf8)!
        try data.write(to: url)
    }

    public func exportLogs(to url: URL) throws {
        try Logger.shared.exportLogs(to: url)
    }
}