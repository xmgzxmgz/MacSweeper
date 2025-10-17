import SwiftUI
import AppKit
import MacSweeperKit
import Quartz

struct ContentView: View {
    @EnvironmentObject var vm: MainViewModel
    @State private var showingPicker = false
    @State private var showWelcome = true
    @State private var showConfirm = false
    @State private var exportAlert: String? = nil
    @State private var selectedCandidate: DeletionCandidate? = nil
    @FocusState private var searchFocused: Bool
    @State private var previewProvider = OneItemPreviewProvider()

    var body: some View {
        NavigationView {
            Sidebar
            MainArea
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showWelcome) {
            WelcomeView(onQuickScan: {
                vm.applyPreset(.standard)
                vm.startAnalysis(paths: vm.quickScanDefaultPaths)
                showWelcome = false
            }, onOpenPicker: {
                showingPicker = true
            })
        }
    }

    private var Sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mac 清风")
                .font(.largeTitle)
                .bold()
            Text(vm.currentStatus)
                .foregroundColor(.secondary)
            ProgressView(value: vm.scanProgress)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("选择目录") { showingPicker = true }
                Button("快速扫描") { vm.applyPreset(.standard); vm.startAnalysis(paths: vm.quickScanDefaultPaths) }
                Button("开始扫描") { selectAndStartIfNeeded() }
                Button("取消扫描") { vm.cancelScan() }
                    .disabled(!vm.isScanning)
                Button("删除选中项") { showConfirm = true }
                    .disabled(vm.deletionCandidates.filter { $0.isMarkedForDeletion }.isEmpty)
            }
            .padding(.top, 8)

            Divider()

            SettingsPanel(vm: vm)

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 280)
        .sheet(isPresented: $showingPicker) {
            DirectoryPicker { urls in
                vm.startAnalysis(paths: urls)
            }
        }
        .sheet(isPresented: $showConfirm) {
            ConfirmDeleteView(count: vm.deletionCandidates.filter { $0.isMarkedForDeletion }.count,
                              size: vm.deletionCandidates.filter { $0.isMarkedForDeletion }.reduce(Int64(0)) { $0 + $1.fileItem.size },
                              dryRun: vm.settings.dryRun) {
                vm.processSelectedDeletions()
                showConfirm = false
            } onCancel: {
                showConfirm = false
            }
        }
    }

    private var MainArea: some View {
        VStack(alignment: .leading) {
            Text("删除建议")
                .font(.title2)
                .padding(.bottom, 8)
            HStack {
                TextField("搜索名称或路径", text: Binding(get: { vm.filters.searchText }, set: { vm.filters.searchText = $0; vm.applyFiltersAndSort() }))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)
                    .focused($searchFocused)
                    .keyboardShortcut("f", modifiers: [.command])
                Spacer()
                Button("全选当前筛选") { vm.selectAllFiltered(true) }
                Button("清空选择") { vm.selectAllFiltered(false) }
                Button("预览") { showQuickLook() }
                    .keyboardShortcut(.space)
                Button("导出JSON") {
                    let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop/MacSweeper_export.json")
                    do { try vm.exportJSON(to: url); exportAlert = "已导出到桌面：MacSweeper_export.json" } catch { exportAlert = "导出失败：\(error.localizedDescription)" }
                }
                Button("导出CSV") {
                    let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop/MacSweeper_export.csv")
                    do { try vm.exportCSV(to: url); exportAlert = "已导出到桌面：MacSweeper_export.csv" } catch { exportAlert = "导出失败：\(error.localizedDescription)" }
                }
            }
            .padding(.bottom, 6)

            List(selection: Binding(get: { selectedCandidate }, set: { selectedCandidate = $0 })) {
                ForEach(vm.filteredCandidates, id: \.self) { candidate in
                    CandidateRow(candidate: candidate) { checked in
                        // 更新选中状态
                        if let idx = vm.deletionCandidates.firstIndex(of: candidate) {
                            vm.deletionCandidates[idx].isMarkedForDeletion = checked
                            vm.applyFiltersAndSort()
                        }
                    }
                    .tag(candidate)
                }
            }
            if let msg = exportAlert {
                Text(msg).foregroundColor(.secondary).font(.footnote)
            }
        }
        .padding(16)
    }

    private func selectAndStartIfNeeded() {
        showingPicker = true
    }
}

struct SummaryView: View {
    let summary: AnalysisSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("扫描文件数：\(summary.totalFilesScanned)")
            Text("可清理总大小：\(formatBytes(summary.totalSizeCleanable))")
            Text("重复文件数：\(summary.duplicateCount)")
            Text("大文件数：\(summary.largeFilesCount)")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var idx = 0
        while value >= 1024 && idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        return String(format: "%.2f %@", value, units[idx])
    }
}

struct CandidateRow: View {
    let candidate: DeletionCandidate
    var onToggle: (Bool) -> Void
    @State private var checked: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Toggle("", isOn: Binding(get: { checked }, set: { newVal in
                checked = newVal
                onToggle(newVal)
            }))
            .toggleStyle(.checkbox)
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.fileItem.url.path)
                    .font(.callout)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    FileIcon(path: candidate.fileItem.url.path)
                        .frame(width: 16, height: 16)
                    Text(candidate.reason)
                }
                .foregroundColor(.secondary)
                .font(.caption)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(formatBytes(candidate.fileItem.size))
                Text(relativeTime(candidate.fileItem.lastAccessDate))
            }
            .foregroundColor(.secondary)
            .font(.caption)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var idx = 0
        while value >= 1024 && idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        return String(format: "%.2f %@", value, units[idx])
    }
}

/// 使用 NSOpenPanel 的目录选择视图
struct DirectoryPicker: View {
    let onPicked: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("选择要扫描的目录")
                .font(.headline)
            Text("点击下方按钮打开系统目录选择器")
                .foregroundColor(.secondary)
            Button("选择目录") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                panel.prompt = "选择"
                if panel.runModal() == .OK {
                    onPicked(panel.urls)
                }
            }
            Button("关闭") {
                NSApp.keyWindow?.close()
            }
        }
        .padding(24)
        .frame(minWidth: 420)
    }
}

struct WelcomeView: View {
    let onQuickScan: () -> Void
    let onOpenPicker: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text("欢迎使用 Mac 清风")
                .font(.title)
                .bold()
            Text("建议先进行快速扫描或自定义选择目录。删除采用废纸篓，安全可撤回。")
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("快速扫描常用路径") { onQuickScan() }
                Button("选择目录开始") { onOpenPicker() }
            }
            Divider().padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("扫描规则与风险提示").font(.headline)
                Text("• 大文件、旧文件、重复与缓存/日志识别")
                Text("• 删除为移动至废纸篓，可从废纸篓恢复")
                Text("• 对系统/外接盘目录谨慎操作，建议仅清理缓存")
            }
        }
        .padding(24)
        .frame(minWidth: 520)
    }
}

struct SettingsPanel: View {
    @ObservedObject var vm: MainViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("摘要与设置").font(.headline)
            SummaryView(summary: vm.analysisSummary)
            HStack {
                Text("预设：")
                Picker("", selection: Binding(get: { vm.settings.preset }, set: { vm.applyPreset($0) })) {
                    Text("轻度").tag(ScanPreset.light)
                    Text("标准").tag(ScanPreset.standard)
                    Text("深度").tag(ScanPreset.deep)
                }
                .pickerStyle(.segmented)
                Spacer()
                Text("排序：")
                Picker("", selection: Binding(get: { vm.settings.sortMode }, set: { vm.settings.sortMode = $0; vm.applyFiltersAndSort() })) {
                    Text("大小优先").tag(SortMode.bySize)
                    Text("低风险优先").tag(SortMode.byLowRisk)
                    Text("最久未用").tag(SortMode.byOldest)
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                TextField("大文件阈值（如 1GB / 500MB）", text: Binding(
                    get: { formatBytesInput(vm.settings.largeThresholdBytes) },
                    set: { if let v = parseSizeToBytes($0) { vm.settings.largeThresholdBytes = v } }
                ))
                TextField("旧文件天数（如 365）", value: Binding(get: { vm.settings.oldDays }, set: { vm.settings.oldDays = $0; }), formatter: NumberFormatter())
                    .frame(width: 100)
                Toggle("查重", isOn: Binding(get: { vm.settings.includeDuplicates }, set: { vm.settings.includeDuplicates = $0 }))
                Toggle("仅预览（Dry-run）", isOn: Binding(get: { vm.settings.dryRun }, set: { vm.settings.dryRun = $0 }))
            }

            HStack(spacing: 12) {
                TextField("排除路径（逗号分隔）", text: Binding(
                    get: { vm.settings.excludePaths.joined(separator: ",") },
                    set: { vm.settings.excludePaths = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                ))
                TextField("排除扩展名（如 psd,aep,zip）", text: Binding(
                    get: { vm.settings.excludeExtensions.joined(separator: ",") },
                    set: { vm.settings.excludeExtensions = $0.split(separator: ",").map { String($0).lowercased().trimmingCharacters(in: .whitespaces) } }
                ))
            }

            HStack(spacing: 12) {
                ForEach(SuggestionKind.allCases, id: \.self) { kind in
                    Toggle(labelFor(kind), isOn: Binding(get: { vm.filters.kinds.contains(kind) }, set: { on in
                        if on { vm.filters.kinds.insert(kind) } else { vm.filters.kinds.remove(kind) }
                        vm.applyFiltersAndSort()
                    }))
                }
            }

            HStack(spacing: 12) {
                TextField("最小大小过滤（如 100MB）", text: Binding(
                    get: { vm.filters.minSizeBytes.map(formatBytesInput) ?? "" },
                    set: { vm.filters.minSizeBytes = parseSizeToBytes($0); vm.applyFiltersAndSort() }
                ))
                TextField("最大大小过滤（如 5GB）", text: Binding(
                    get: { vm.filters.maxSizeBytes.map(formatBytesInput) ?? "" },
                    set: { vm.filters.maxSizeBytes = parseSizeToBytes($0); vm.applyFiltersAndSort() }
                ))
            }
        }
        .padding(.top, 8)
    }

    private func labelFor(_ k: SuggestionKind) -> String {
        switch k { case .large: return "大文件"; case .old: return "旧文件"; case .duplicate: return "重复"; case .cacheLog: return "缓存/日志" }
    }
}

struct ConfirmDeleteView: View {
    let count: Int
    let size: Int64
    let dryRun: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text(dryRun ? "预览模式：不会进行实际删除" : "确认删除选中项")
                .font(.headline)
            Text("数量：\(count)  项，总大小：\(formatBytes(size))")
            HStack(spacing: 12) {
                Button(dryRun ? "生成报告" : "确认删除") { onConfirm() }
                Button("取消") { onCancel() }
            }
            Text("说明：删除将移动到废纸篓，可通过废纸篓还原。")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .padding(24)
        .frame(minWidth: 460)
    }
}

struct FileIcon: View {
    let path: String
    var body: some View {
        if let nsimg = NSWorkspace.shared.icon(forFile: path) as NSImage? {
            Image(nsImage: nsimg).resizable().scaledToFit()
        } else {
            Image(systemName: "doc")
        }
    }
}

final class OneItemPreviewProvider: NSObject, QLPreviewPanelDataSource {
    var itemURL: URL?
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { itemURL == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return itemURL as NSURL?
    }
}

private extension ContentView {
    func showQuickLook() {
        guard let url = selectedCandidate?.fileItem.url else { return }
        previewProvider.itemURL = url
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = previewProvider
            panel.makeKeyAndOrderFront(nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Helpers
private func parseSizeToBytes(_ s: String) -> Int64? {
    let lower = s.lowercased().trimmingCharacters(in: .whitespaces)
    if lower.hasSuffix("kb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024) }
    if lower.hasSuffix("mb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024) }
    if lower.hasSuffix("gb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024 * 1024) }
    return Int64(lower)
}

private func formatBytesInput(_ bytes: Int64) -> String {
    if bytes % (1024*1024*1024) == 0 { return "\(bytes / (1024*1024*1024))GB" }
    if bytes % (1024*1024) == 0 { return "\(bytes / (1024*1024))MB" }
    if bytes % 1024 == 0 { return "\(bytes / 1024)KB" }
    return "\(bytes)"
}

private func relativeTime(_ date: Date?) -> String {
    guard let date else { return "无访问记录" }
    let diff = Int(Date().timeIntervalSince(date))
    let days = diff / (24*3600)
    if days >= 1 { return "访问于 \(days) 天前" }
    let hours = (diff % (24*3600)) / 3600
    if hours >= 1 { return "访问于 \(hours) 小时前" }
    let minutes = (diff % 3600) / 60
    return "访问于 \(minutes) 分钟前"
}