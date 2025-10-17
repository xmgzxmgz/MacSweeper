import SwiftUI
import AppKit
import MacSweeperKit

@main
struct MacSweeperApp: App {
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .commands {
            CommandMenu("Mac 清风") {
                Button("选择目录并开始扫描") {
                    selectDirectoriesAndScan()
                }.keyboardShortcut("r", modifiers: [.command])

                Button("快速扫描默认路径") {
                    viewModel.applyPreset(.standard)
                    viewModel.startAnalysis(paths: viewModel.quickScanDefaultPaths)
                }.keyboardShortcut("r", modifiers: [.command, .shift])

                Button("取消扫描") {
                    viewModel.cancelScan()
                }.keyboardShortcut(".", modifiers: [.command])

                Divider()

                Button("删除选中项") {
                    viewModel.processSelectedDeletions()
                }.keyboardShortcut(.delete, modifiers: [.command])
            }
        }
    }

    private func selectDirectoriesAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            let urls = panel.urls
            viewModel.startAnalysis(paths: urls)
        }
    }
}