<div align="center">

# Mac 清风 (MacSweeper)

[![CI](https://github.com/xmgzxmgz/MacSweeper/actions/workflows/ci.yml/badge.svg)](https://github.com/xmgzxmgz/MacSweeper/actions/workflows/ci.yml)

**智能 Mac 文件清理工具 -- 分析磁盘，给出安全删除建议**

[![Swift](https://img.shields.io/badge/Swift-5.7+-orange?style=flat-square&logo=swift)](https://swift.org/)
[![Platform](https://img.shields.io/badge/platform-macOS%2012+-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-v1.0-blue?style=flat-square)](https://github.com/xmgzxmgz/MacSweeper/releases)

一个用 Swift 编写的 Mac 磁盘分析工具，扫描系统中的冗余文件、缓存、大文件等，给出安全的删除建议。

[功能特性](#功能特性) · [快速开始](#快速开始) · [项目结构](#项目结构) · [使用方法](#使用方法) · [开发计划](#开发计划)

</div>

---

## 功能特性

- **磁盘扫描** -- 快速扫描指定目录，分析文件占用
- **智能分析** -- 识别大文件、旧文件、重复文件、缓存/日志、云占位文件
- **删除建议** -- 基于分析结果给出安全的删除建议，含风险等级标注
- **安全优先** -- 删除移至废纸篓，保护系统关键数据，可随时撤回
- **CLI 工具** -- 命令行版本，适合终端用户和脚本集成
- **GUI 应用** -- SwiftUI 原生界面，支持 QuickLook 预览、JSON/CSV 导出
- **查重引擎** -- 基于 SHA256 的文件内容去重，支持快速采样模式
- **扫描历史** -- 自动记录最近 50 次扫描结果，便于追踪

---

## 快速开始

### 环境要求

| 依赖 | 版本 |
|------|------|
| macOS | 12.0+ |
| Swift | 5.7+ |
| Xcode | 14+（推荐最新版） |

### 安装

#### 方式一：使用 Makefile（推荐）

```bash
git clone https://github.com/xmgzxmgz/MacSweeper.git
cd MacSweeper

# 构建并安装 CLI 到 /usr/local/bin
make install

# 验证安装
MacSweeperCLI --help
```

#### 方式二：使用 SwiftPM

```bash
git clone https://github.com/xmgzxmgz/MacSweeper.git
cd MacSweeper

# 构建 CLI
swift build -c release --product MacSweeperCLI

# 运行
.build/release/MacSweeperCLI --help
```

#### 方式三：使用 Xcode

```bash
git clone https://github.com/xmgzxmgz/MacSweeper.git
open MacSweeper/Package.swift
```

Xcode 会自动打开项目，选择 `MacSweeperApp` scheme 运行 GUI 应用。

### 常见问题

如果遇到 `this SDK is not supported by the compiler` 错误：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 项目结构

```
MacSweeper/
├── Sources/
│   ├── MacSweeperKit/              # 核心库（可独立使用）
│   │   ├── Analyzer.swift          # 文件分析引擎（5 种规则）
│   │   ├── Models.swift            # 数据模型
│   │   ├── MainViewModel.swift     # MVVM 视图模型
│   │   ├── Settings.swift          # 配置管理
│   │   ├── Utilities.swift         # 共享工具函数
│   │   └── Services/
│   │       ├── FileManagerService.swift  # 文件系统操作
│   │       ├── HashService.swift         # SHA256 哈希与缓存
│   │       ├── Logger.swift              # 日志服务
│   │       └── ScanHistoryService.swift  # 扫描历史记录
│   ├── MacSweeperCLI/              # 命令行工具
│   │   └── main.swift              # CLI 入口
│   └── MacSweeperApp/              # SwiftUI GUI 应用
│       ├── App.swift               # 应用入口
│       └── ContentView.swift       # 主视图
├── Distribution/
│   └── Info.plist                  # App 元信息
├── Package.swift                   # Swift Package 配置
├── Makefile                        # 构建脚本
└── README.md
```

---

## 使用方法

### CLI 模式

```bash
# 显示帮助
MacSweeperCLI --help

# 显示版本
MacSweeperCLI --version

# 扫描当前目录
MacSweeperCLI

# 扫描指定目录
MacSweeperCLI ~/Downloads ~/Desktop

# 自定义阈值
MacSweeperCLI --large=500MB --old=180 ~/Documents

# 跳过查重，导出结果
MacSweeperCLI --no-duplicates --json=result.json ~/Library/Caches

# 导出为 CSV
MacSweeperCLI --csv=report.csv ~/Downloads
```

### CLI 输出示例

```
MacSweeper (Mac 清风) v0.1.0 -- 开始扫描...
扫描: /Users/user/Downloads
  找到 342 个文件

========================================
  MacSweeper -- 分析摘要
========================================
  扫描文件数:   342
  可清理总大小: 2.35 GB
  大文件数:     3
  旧文件数:     12
  重复文件数:   8
  缓存/日志数:  15
  云占位文件数: 0
========================================

建议删除列表（前 50 条）:

  [高风险] 大文件（>=1.00 GB）
    路径: /Users/user/Downloads/large-video.mp4
    大小: 1.85 GB

  [低风险] 重复文件（内容一致）
    路径: /Users/user/Downloads/photo-copy.jpg
    大小: 4.50 MB

  [低风险] 缓存/日志目录中的文件
    路径: /Users/user/Library/Caches/com.apple.Safari/Cache.db
    大小: 120.00 MB
```

### Makefile 命令

```bash
make cli         # 构建 CLI (release)
make app         # 构建 GUI (release)
make release     # 构建全部
make debug       # Debug 构建
make install     # 安装到 /usr/local/bin
make scan        # 快速扫描当前目录
make clean       # 清理构建产物
make help        # 显示所有命令
```

---

## 架构设计

```
MacSweeperKit (核心库)
├── Analyzer        -- 5 种文件分析规则引擎
├── Models          -- FileItem, DeletionCandidate, AnalysisSummary
├── Services        -- FileManager, Hash, Logger, History
├── Settings        -- UserSettings, FilterOptions, Presets
├── Utilities       -- formatBytes, parseSizeToBytes, relativeTime
└── MainViewModel   -- MVVM 视图模型（线程安全扫描）

MacSweeperCLI       -- CLI 入口，调用 Kit 库
MacSweeperApp       -- SwiftUI GUI，调用 Kit 库
```

### 分析规则

| 规则 | 说明 | 默认风险 |
|------|------|----------|
| 大文件 | 超过阈值（默认 1GB）的文件 | 高 |
| 旧文件 | 超过指定天数（默认 365）未访问 | 中 |
| 重复文件 | SHA256 内容相同的文件 | 低 |
| 缓存/日志 | Library/Caches 或 Logs 目录下 | 低 |
| 云占位文件 | iCloud/Dropbox 未下载项 | 高 |

---

## 开发计划

- [x] 核心分析引擎（5 种规则）
- [x] CLI 命令行工具（支持 --help、--json、--csv）
- [x] SwiftUI GUI 应用（QuickLook 预览、导出）
- [x] 文件哈希查重（SHA256 + 快速采样模式）
- [x] 安全删除（移到废纸篓）
- [x] 扫描历史记录（最近 50 次）
- [ ] Xcode 工程文件（.xcodeproj）
- [ ] 定时扫描计划（LaunchAgent）
- [ ] 应用沙盒支持
- [ ] 分类优化（浏览器缓存、Xcode DerivedData 等）
- [ ] 多语言支持（英文界面）

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

## 作者

**xmgz**
- Email: 通过 GitHub Issues 联系
- GitHub: [@xmgzxmgz](https://github.com/xmgzxmgz)

---

<div align="center">

**如果觉得有用，请给个 Star！**

</div>
