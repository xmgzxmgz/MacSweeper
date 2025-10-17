# Mac 清风 (MacSweeper)

一个用于分析 Mac 文件并给出删除建议的工具。当前仓库包含：

- `MacSweeperKit`：核心库（模型、服务、分析引擎）
- `MacSweeperCLI`：命令行工具，便于快速分析和查看建议

> 后续将基于此核心库接入 SwiftUI，构建 macOS GUI 应用。

## 构建与运行（CLI）

1. 安装/切换到匹配的 Xcode 工具链（修复下述错误）：

   如果你在 `swift build` 时遇到如下错误：

   ```
   this SDK is not supported by the compiler ... Please select a toolchain which matches the SDK.
   ```

   说明系统的 Command Line Tools 与 Swift 编译器版本不匹配。请按以下步骤修复：

   - 确认系统已安装完整 Xcode：从 App Store 安装或更新到最新版本。
   - 切换到 Xcode 附带的开发者目录：
     ```bash
     sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
     ```
   - 或者重新安装命令行工具：
     ```bash
     xcode-select --install
     ```
   - 重启终端后再次执行 `swift build`。

2. 构建项目：

   ```bash
   swift build
   ```

3. 运行 CLI：

   ```bash
   ./.build/debug/MacSweeperCLI [路径1 路径2 ...] [--large=1GB] [--old=365] [--no-duplicates]
   ```

   示例：

   ```bash
   ./.build/debug/MacSweeperCLI ~/Downloads --large=2GB --old=180
   ```

   输出包括：扫描文件总数、可清理总大小、重复文件数与大文件数，以及前 50 条删除建议。

## 分析规则

- 大文件：默认 ≥ 1GB，可通过 `--large=2GB` 等参数调整
- 旧文件：默认 ≥ 365 天未访问，可用 `--old=180` 调整
- 重复文件：默认开启，按大小+SHA256 内容哈希识别；可用 `--no-duplicates` 关闭
- 缓存/日志：匹配路径中含 `/Library/Caches` 和 `/Library/Logs`

## 目录结构

- `Sources/MacSweeperKit/Models.swift`：FileItem、DeletionCandidate、AnalysisSummary
- `Sources/MacSweeperKit/Services/FileManagerService.swift`：扫描目录与安全删除（废纸篓）
- `Sources/MacSweeperKit/Services/HashService.swift`：SHA256 计算（CryptoKit）
- `Sources/MacSweeperKit/Analyzer.swift`：分析规则与摘要统计
- `Sources/MacSweeperKit/MainViewModel.swift`：预留给 SwiftUI 的 ViewModel（MVVM）
- `Sources/MacSweeperCLI/main.swift`：CLI 参数解析与输出

## 接入 SwiftUI（后续）

当工具链可用、且你准备创建 GUI 应用时：

1. 在 Xcode 中创建新的 `macOS App (SwiftUI)` 工程，名称使用：`Mac 清风 (MacSweeper)`。
2. 将当前包作为本地依赖导入：在 Xcode 工程的 `Package Dependencies` 添加本地包路径（本仓库根目录）。
3. 在 `App` 和各个 `View` 中引入 `MacSweeperKit`：
   - 在 `App` 入口中创建并注入 `MainViewModel()` 到环境
   - `DashboardView` 绑定 `analysisSummary` 和 `scanProgress`
   - `ResultDetailView` 列表绑定 `deletionCandidates` 并提供“删除选中项”按钮调用 `processSelectedDeletions()`
4. 使用 `NSOpenPanel` 或 `FileImporter` 请求用户选择扫描目录，并调用 `startAnalysis(paths:)`。

> 备注：CLI 中的同步扫描为了易用；SwiftUI 中可将扫描逻辑迁移到后台线程或采用 `AsyncSequence` 以避免阻塞 UI。

## 安全性与注意事项

- 删除使用 `FileManager.trashItem`，移动至废纸篓，避免误删。
- 对重复文件的建议为除保留一个外的其他副本，仍需用户确认。
- 访问某些目录可能受沙盒/权限限制，GUI 应用中需显式请求权限。