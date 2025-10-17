import Foundation
import MacSweeperKit

struct CLIOptions {
    var paths: [URL] = []
    var largeThresholdBytes: Int64 = 1_000_000_000 // 1GB
    var oldDays: Int = 365
    var includeDuplicates: Bool = true
}

func parseOptions() -> CLIOptions {
    var opts = CLIOptions()
    let args = CommandLine.arguments.dropFirst()

    var idx = 0
    while idx < args.count {
        let arg = args[args.index(args.startIndex, offsetBy: idx)]
        if arg.hasPrefix("--large=") {
            let value = arg.replacingOccurrences(of: "--large=", with: "")
            if let bytes = parseSizeToBytes(value) { opts.largeThresholdBytes = bytes }
        } else if arg.hasPrefix("--old=") {
            let value = arg.replacingOccurrences(of: "--old=", with: "")
            if let days = Int(value) { opts.oldDays = days }
        } else if arg == "--no-duplicates" {
            opts.includeDuplicates = false
        } else if arg.hasPrefix("--") {
            // 未知参数忽略
        } else {
            let url = URL(fileURLWithPath: arg)
            opts.paths.append(url)
        }
        idx += 1
    }
    if opts.paths.isEmpty {
        // 默认当前目录
        opts.paths = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
    }
    return opts
}

func parseSizeToBytes(_ s: String) -> Int64? {
    // 支持 500MB、1GB、1024KB、数字视为字节
    let lower = s.lowercased()
    if lower.hasSuffix("kb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024) }
    if lower.hasSuffix("mb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024) }
    if lower.hasSuffix("gb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024 * 1024) }
    return Int64(lower)
}

func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var idx = 0
    while value >= 1024 && idx < units.count - 1 {
        value /= 1024
        idx += 1
    }
    return String(format: "%.2f %@", value, units[idx])
}

func main() {
    let opts = parseOptions()
    let fmService = FileManagerService()
    let analyzer = Analyzer()

    var allItems: [FileItem] = []
    for url in opts.paths {
        guard fmService.requestAccess(to: url) else { continue }
        let items = fmService.scanDirectory(at: url)
        allItems.append(contentsOf: items)
    }

    var candidates: [DeletionCandidate] = []
    candidates += analyzer.identifyLargeFiles(items: allItems, thresholdBytes: opts.largeThresholdBytes)
    candidates += analyzer.identifyOldFiles(items: allItems, olderThanDays: opts.oldDays)
    if opts.includeDuplicates {
        candidates += analyzer.identifyDuplicates(items: allItems)
    }
    candidates += analyzer.identifyCacheAndLogs(items: allItems)

    let summary = analyzer.summarize(candidates: candidates, totalScanned: allItems.count)

    print("MacSweeper —— 分析摘要")
    print("扫描文件数: \(summary.totalFilesScanned)")
    print("可清理总大小: \(formatBytes(summary.totalSizeCleanable))")
    print("重复文件数: \(summary.duplicateCount)")
    print("大文件数: \(summary.largeFilesCount)")
    print("")
    print("建议删除列表（前 50 条）:")
    for candidate in candidates.prefix(50) {
        print("- \(candidate.reason): \(candidate.fileItem.url.path)  [\(formatBytes(candidate.fileItem.size))]")
    }

    print("")
    print("使用：MacSweeperCLI [路径1 路径2 ...] [--large=1GB] [--old=365] [--no-duplicates]")
}

main()