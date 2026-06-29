import Foundation
import MacSweeperKit

// MARK: - Version

let appVersion = "1.0.0"

// MARK: - CLI Options

struct CLIOptions {
    var paths: [URL] = []
    var largeThresholdBytes: Int64 = 1_000_000_000
    var oldDays: Int = 365
    var includeDuplicates: Bool = true
    var showHelp: Bool = false
    var showVersion: Bool = false
    var exportJSON: String? = nil
    var exportCSV: String? = nil
}

// MARK: - Argument Parsing

func printHelp() {
    let help = """
    MacSweeper (Mac 清风) v\(appVersion) — macOS 智能文件清理工具

    用法: MacSweeperCLI [选项] [路径...]

    参数:
      [路径...]               要扫描的目录路径（默认为当前目录）

    选项:
      --large=<大小>          大文件阈值（如 1GB, 500MB），默认 1GB
      --old=<天数>            旧文件天数阈值，默认 365 天
      --no-duplicates         跳过重复文件检测
      --json=<文件路径>       将结果导出为 JSON 文件
      --csv=<文件路径>        将结果导出为 CSV 文件
      --help, -h              显示此帮助信息
      --version, -v           显示版本号

    示例:
      MacSweeperCLI ~/Downloads ~/Desktop
      MacSweeperCLI --large=500MB --old=180 ~/Documents
      MacSweeperCLI --no-duplicates --json=result.json ~/Library/Caches

    注意: 删除操作仅在 GUI 版本中可用。CLI 版本仅进行分析并显示建议。
    """
    print(help)
}

func printVersion() {
    print("MacSweeper (Mac 清风) v\(appVersion)")
}

func parseOptions() -> CLIOptions {
    var opts = CLIOptions()
    let args = CommandLine.arguments.dropFirst()

    var idx = 0
    while idx < args.count {
        let arg = args[args.index(args.startIndex, offsetBy: idx)]

        if arg == "--help" || arg == "-h" {
            opts.showHelp = true
        } else if arg == "--version" || arg == "-v" {
            opts.showVersion = true
        } else if arg.hasPrefix("--large=") {
            let value = String(arg.dropFirst("--large=".count))
            if let bytes = parseSizeToBytes(value) {
                opts.largeThresholdBytes = bytes
            } else {
                fputs("警告: 无法解析 --large 参数值: \(value)，使用默认值 1GB\n", stderr)
            }
        } else if arg.hasPrefix("--old=") {
            let value = String(arg.dropFirst("--old=".count))
            if let days = Int(value), days > 0 {
                opts.oldDays = days
            } else {
                fputs("警告: 无法解析 --old 参数值: \(value)，使用默认值 365 天\n", stderr)
            }
        } else if arg == "--no-duplicates" {
            opts.includeDuplicates = false
        } else if arg.hasPrefix("--json=") {
            opts.exportJSON = String(arg.dropFirst("--json=".count))
        } else if arg.hasPrefix("--csv=") {
            opts.exportCSV = String(arg.dropFirst("--csv=".count))
        } else if arg.hasPrefix("--") {
            fputs("警告: 未知参数: \(arg)，已忽略\n", stderr)
        } else {
            opts.paths.append(URL(fileURLWithPath: arg))
        }
        idx += 1
    }

    if opts.paths.isEmpty && !opts.showHelp && !opts.showVersion {
        opts.paths = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
    }
    return opts
}

// MARK: - Main

func runCLI() {
    let opts = parseOptions()

    if opts.showVersion {
        printVersion()
        return
    }
    if opts.showHelp {
        printHelp()
        return
    }

    let fmService = FileManagerService()
    let analyzer = Analyzer()

    fputs("MacSweeper (Mac 清风) v\(appVersion) — 开始扫描...\n", stderr)

    var allItems: [FileItem] = []
    for url in opts.paths {
        let path = url.path
        guard fmService.requestAccess(to: url) else {
            fputs("警告: 无法访问路径: \(path)\n", stderr)
            continue
        }
        fputs("扫描: \(path)\n", stderr)
        let items = fmService.scanDirectory(at: url)
        allItems.append(contentsOf: items)
        fputs("  找到 \(items.count) 个文件\n", stderr)
    }

    var candidates: [DeletionCandidate] = []
    candidates += analyzer.identifyLargeFiles(items: allItems, thresholdBytes: opts.largeThresholdBytes)
    candidates += analyzer.identifyOldFiles(items: allItems, olderThanDays: opts.oldDays)
    if opts.includeDuplicates {
        candidates += analyzer.identifyDuplicates(items: allItems)
    }
    candidates += analyzer.identifyCacheAndLogs(items: allItems)
    candidates += analyzer.identifyCloudPlaceholders(items: allItems)
    candidates = analyzer.applyProtections(candidates: candidates)

    let summary = analyzer.summarize(candidates: candidates, totalScanned: allItems.count)

    print("")
    print("========================================")
    print("  MacSweeper — 分析摘要")
    print("========================================")
    print("  扫描文件数:   \(summary.totalFilesScanned)")
    print("  可清理总大小: \(formatBytes(summary.totalSizeCleanable))")
    print("  大文件数:     \(summary.largeFilesCount)")
    print("  旧文件数:     \(summary.oldFilesCount)")
    print("  重复文件数:   \(summary.duplicateCount)")
    print("  缓存/日志数:  \(summary.cacheLogCount)")
    print("  云占位文件数: \(summary.cloudPlaceholderCount)")
    print("========================================")
    print("")
    print("建议删除列表（前 50 条）:")
    print("")

    for candidate in candidates.prefix(50) {
        let risk: String
        switch candidate.riskLevel {
        case .low: risk = "低风险"
        case .medium: risk = "中风险"
        case .high: risk = "高风险"
        case .none: risk = "未知"
        }
        print("  [\(risk)] \(candidate.reason)")
        print("    路径: \(candidate.fileItem.url.path)")
        print("    大小: \(formatBytes(candidate.fileItem.size))")
        print("")
    }

    if candidates.count > 50 {
        print("  ... 还有 \(candidates.count - 50) 条建议未显示")
        print("")
    }

    // 导出 JSON
    if let jsonPath = opts.exportJSON {
        let url = URL(fileURLWithPath: jsonPath)
        do {
            let vm = MainViewModel()
            vm.deletionCandidates = candidates
            vm.filteredCandidates = candidates
            try vm.exportJSON(to: url)
            print("已导出 JSON: \(jsonPath)")
        } catch {
            fputs("错误: JSON 导出失败: \(error.localizedDescription)\n", stderr)
        }
    }

    // 导出 CSV
    if let csvPath = opts.exportCSV {
        let url = URL(fileURLWithPath: csvPath)
        do {
            let vm = MainViewModel()
            vm.deletionCandidates = candidates
            vm.filteredCandidates = candidates
            try vm.exportCSV(to: url)
            print("已导出 CSV: \(csvPath)")
        } catch {
            fputs("错误: CSV 导出失败: \(error.localizedDescription)\n", stderr)
        }
    }
}

runCLI()
