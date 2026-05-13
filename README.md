# WezTerm & LazyVim Portable Environment

这是一个高度定制化、支持离线便携的终端与编辑器工作流环境。包含经过优化的 WezTerm 终端模拟器、Starship 命令行提示符，以及基于 LazyVim 的 Neovim 现代化编辑器配置。

## ✨ 核心特性

- **完全便携与离线化**：分为 \install\(下载) 和 \setup\(配置) 两个阶段。Neovim 的插件、Mason 包、Treesitter 解析器统一放在本地 \Tools/nvim-data\ 中，可以一键拷贝到无网环境直接使用。
- **现代化终端 UI (WezTerm)**：
  - 亚克力半透明背景与沉浸式 UI。
  - 集成 Gnome 风格窗口控件（最小化、最大化、关闭）。
  - 使用稳定的原生 Fancy 标签栏。
- **高效命令行 (Starship)**：使用具有辨识度的单行/多行展示，路径栏单独显色，命令输入区域清爽分离。
- **增强型编辑器 (LazyVim)**：
  - 使用标准的 LazyVim 官方配置为底座。
  - 基于 Treesitter 的 **Winbar 代码上下文**：支持光标所在处，实时提示光标位于哪个类和函数内。
  - 采用绝对行号设计，适应非相对行视角的直观阅读习惯。

## 🚀 如何使用

这套工程的设计被清晰地切割为**获取环境**与**配置生效**两方面，以便应对多种网络环境：

### 1. 下载环境依赖 🌐 (仅需在联网电脑上执行一次)

如果你需要拉取最新的底层程序二进制压缩包和字体资源：
\\\powershell
# 在 Windows 系统下执行
.\downloads\scripts\install.ps1

# 在 Linux 系统下执行
bash ./downloads/scripts/install.sh
\\\

### 2. 部署与环境生效 💻 (在最终工作目标机上安装)

只要 \downloads\ 目录下存放着已下载好的缓存包，即便断网，在任意目标机器上只需运行配置脚本即可自动完成程序部署。

\\\powershell
.\setup.ps1
\\\

执行该命令后将会实现下列自动化过程：
1. 自动将开发包（WezTerm, Nvim, LazyGit, Yazi 等）解压并部署在同一级 \Tools\ 工作目录下。
2. 强制 Neovim 依赖环境的数据生成在便携目录 \Tools/nvim-data\ 内。
3. 把 WezTerm 配置（包含 Starship 和 Bash）同步拷贝至用户的 \~/.wezterm-config\ 并建立系统级别的 \.wezterm.lua\ 入口软链。
4. 注册 Windows 右键菜单功能，以便通过右键随时唤起该配置环境终端。

### 3. 打开开始编程 🔥
启动 \WezTerm\ 快捷方式进入终端环境。终端下可随时键入 \
vim\ 即刻享受全功能的本地编辑器！
