<div align="center">

# 🧹 Mac 清风 (MacSweeper)

**智能 Mac 文件清理工具 — 分析磁盘，给出安全删除建议**

[![Swift](https://img.shields.io/badge/Swift-5.7+-orange?style=flat-square&logo=swift)](https://swift.org/)
[![Platform](https://img.shields.io/badge/platform-macOS%2012+-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-v1.0-blue?style=flat-square)](https://github.com/xmgzxmgz/MacSweeper/releases)

一个用 Swift 编写的 Mac 磁盘分析工具，扫描系统中的冗余文件、缓存、大文件等，给出安全的删除建议。

[功能特性](#功能特性) · [快速开始](#快速开始) · [项目结构](#项目结构) · [使用方法](#使用方法) · [开发计划](#开发计划)

</div>

---

## ✨ 功能特性

- 🔍 **磁盘扫描** — 快速扫描指定目录，分析文件占用
- 📊 **智能分析** — 识别缓存、日志、临时文件、大文件等
- 💡 **删除建议** — 基于分析结果给出安全的删除建议
- 🛡️ **安全优先** — 只建议删除安全文件，保护系统关键数据
- ⌨️ **CLI 工具** — 命令行版本，适合终端用户和脚本集成
- 🖥️ **GUI 计划** — SwiftUI 界面开发中

---

## 🚀 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| macOS | 12.0+ |
| Swift | 5.7+ |
| Xcode | 14+（推荐最新版） |

### 构建

```bash
# 克隆仓库
git clone https://github.com/xmgzxmgz/MacSweeper.git
cd MacSweeper

# 构建 CLI 工具
swift build -c release

# 运行
.build/release/MacSweeperCLI
```

### 常见问题

如果遇到 `this SDK is not supported by the compiler` 错误：

```bash
# 切换到 Xcode 工具链
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 或重新安装命令行工具
xcode-select --install
```

---

## 📁 项目结构

```
MacSweeper/
├── Sources/
│   ├── MacSweeperKit/          # 核心库
│   │   ├── Analyzer.swift      # 文件分析引擎
│   │   ├── Models.swift        # 数据模型
│   │   ├── MainViewModel.swift # 视图模型
│   │   ├── Settings.swift      # 配置管理
│   │   └── Services/           # 服务层
│   ├── MacSweeperCLI/          # 命令行工具
│   │   └── main.swift          # CLI 入口
│   └── MacSweeperApp/          # SwiftUI GUI（开发中）
│       ├── App.swift           # 应用入口
│       └── ContentView.swift   # 主视图
├── Package.swift               # Swift Package 配置
└── README.md
```

---

## 📖 使用方法

### CLI 模式

```bash
# 扫描当前目录
.build/release/MacSweeperCLI

# 扫描指定目录
.build/release/MacSweeperCLI --path ~/Downloads

# 查看帮助
.build/release/MacSweeperCLI --help
```

### 输出示例

```
🔍 扫描完成: ~/Downloads
📊 总大小: 2.3 GB

建议清理:
  📁 缓存文件     450 MB  (安全删除)
  📄 重复文件     180 MB  (建议检查)
  📦 大文件       1.2 GB  (>100MB, 建议确认)
  🗑️ 临时文件      85 MB  (安全删除)

预估可释放: 715 MB
```

---

## 🏗️ 架构设计

```
MacSweeperKit (核心库)
├── Analyzer      — 文件扫描和分析引擎
├── Models        — 数据模型（文件信息、分析结果）
├── Services      — 文件系统操作服务
├── Settings      — 配置管理（扫描路径、规则）
└── MainViewModel — MVVM 视图模型

MacSweeperCLI     — CLI 入口，调用 Kit 库
MacSweeperApp     — SwiftUI GUI，调用 Kit 库
```

---

## 🗺️ 开发计划

- [x] 核心分析引擎
- [x] CLI 命令行工具
- [ ] SwiftUI GUI 应用
- [ ] 批量删除功能
- [ ] 扫描结果导出（JSON/CSV）
- [ ] 定时扫描计划
- [ ] 垃圾分类优化（应用缓存、浏览器缓存、Xcode 缓存等）
- [ ] 安全删除（移到废纸篓而非直接删除）

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

## 👨‍💻 作者

**xmgz**
- 📧 Email: [xmgzdm@gmail.com](mailto:xmgzdm@gmail.com)
- 🐙 GitHub: [@xmgzxmgz](https://github.com/xmgzxmgz)

---

<div align="center">

**如果觉得有用，请给个 ⭐ Star！**

</div>
