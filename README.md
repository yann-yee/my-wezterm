# WezTerm Windows 开发环境

这是一套面向 Windows 的便携式 WezTerm 配置。默认进入 Git Bash，围绕“终端 + 文件树 + Neovim + Git 看板 + SSH”组织日常开发工作流，并尽量把配置、脚本和工具放在仓库内，方便多台机器同步。

## 快速开始

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

安装脚本会完成这些事：

- 复制仓库内的 `wezterm/` 到 `%USERPROFILE%\.wezterm-config\wezterm`
- 写入 `%USERPROFILE%\.wezterm.lua` 作为 WezTerm 入口
- 复制本地字体、工具和离线安装包
- 安装或复用 Starship
- 创建 `~/.ssh/cm`，并把仓库内 SSH 默认配置 Include 到 `~/.ssh/config`

如果 WezTerm/Yazi 正在运行，部分可执行文件可能被锁定；脚本会尽量更新配置文件，并提示关闭后重跑以完成完整同步。

仓库 `downloads/` 当前附带这些 Windows 离线安装/分发文件：`WezTerm`、`Git for Windows`、`Neovim`、`Starship`、`tree-sitter` CLI、`bat`、`eza`、`lazygit`、`yazi`。

运行前提分两层：

- 必需：`WezTerm`、`Git for Windows`、`Neovim`
- 建议：C/C++ 后续手动装 `clangd`；Python 装 `basedpyright`、`pyright` 或 `pylsp`

`tree-sitter` CLI 是可选增强，不是这套工作流的必需前提。仓库会保留它的离线分发文件，但 Neovim 仍不会默认替你自动安装 parser。没有它时，LSP 跳转/补全仍然可以正常工作；只是少一部分语法高亮和缩进行为。

## 已包含能力

- Git Bash 默认 shell
- Starship 多行 prompt、右侧时间/状态、渐变命令分隔线
- Bash completion、Git completion、Tab 菜单补全、前缀历史搜索
- `yazi` 单列文件浏览器
- `lazygit` Git 看板
- `bat` 代码高亮、`eza` 图标列表
- 仓库内 Neovim 配置：状态栏、模式高亮、行号区样式、代码上下文显示
- 同窗口新标签页打开文件，避免分窗挤压
- WezTerm 分窗、标签页、搜索、快速选择、复制模式、字号调整、窗口置顶
- SSH keepalive、连接复用、主机别名辅助
- Neovim 内语义跳转：C/C++ 优先走 `clangd`，Python 优先走 LSP，失败后回退 `jedi` / `ctags`
- 首次启动可自动拉取 `lazy.nvim` 和内置插件配置；如果已有本地仓库，也可直接复用

## 离线安装包

`downloads/` 目录现在面向“新机器一次配齐”保留这些内容：

- `WezTerm-...-setup.exe`：终端本体
- `Git-...-64-bit.exe`：Git Bash 与 Git
- `nvim-win64.msi`：Neovim
- `starship-...msi`：提示符
- `tree-sitter-windows-x64.gz`：可选的 `tree-sitter` CLI
- `bat` / `eza` / `lazygit` / `yazi` 压缩包：仓库内工具分发

字体文件已经直接跟随 [wezterm/fonts/JetBrainsMonoNerdFont](c:/Users/qwer/Desktop/wezterm-config/wezterm/fonts/JetBrainsMonoNerdFont) 一起入库，不再额外保留一个超大的离线压缩包。

`clangd` 仍然按“后续手动安装”处理，不放进默认离线包。`tree-sitter` CLI 也仍然按可选项处理；只有你主动开启 `WEZTERM_NVIM_AUTO_INSTALL_PARSERS=1` 并且本机已准备好 `tree-sitter`、编译器、`curl`、`tar` 时，Neovim 才会尝试自动安装 parser。

## 日常工作流

### 文件树

按 `Ctrl+Alt+T` 打开左侧 Yazi 文件树，再按一次关闭。文件树是单列布局：

- 点击目录：进入目录
- 点击文本文件：在当前 WezTerm 窗口内新建标签页，打开 Git Bash + Neovim
- 打开的 Neovim 会加载 [wezterm/nvim/init.lua](wezterm/nvim/init.lua)

在 Git Bash 里直接执行 `nvim 文件` 会走同窗口新标签页；`vim 文件` 作为兼容别名也会转发到 Neovim。不带文件参数的 `nvim` / `vim` 仍会在当前窗格打开。

### 标签页

当前打开文件的默认方式是“同窗口新标签页”，不是分窗，也不是新窗口。这样多开几个文件时不会挤压当前布局。

常用操作：

- `Ctrl+Shift+T`：新建标签页
- `Ctrl+Shift+W`：关闭当前标签页
- `Ctrl+Tab` / `Ctrl+Shift+Tab`：切换标签页
- `Alt+1` 到 `Alt+9`：跳到指定标签页
- `Ctrl+Shift+Left` / `Ctrl+Shift+Right`：移动当前标签页位置
- `Ctrl+Alt+,`：重命名当前标签页

### 分窗

分窗现在主要用于临时布局，比如左边跑服务、右边看日志，或者右侧打开 lazygit。

- `Ctrl+Alt+Enter`：上下分窗
- `Ctrl+Alt+\`：左右分窗
- `Ctrl+Alt+h/j/k/l`：切换到左/下/上/右窗格
- `Ctrl+Alt+Shift+方向键`：调整窗格大小
- `Ctrl+Alt+z`：放大 / 还原当前窗格
- `Ctrl+Alt+x`：关闭当前窗格

特殊分窗入口：

- `Ctrl+Alt+T`：左侧文件树
- `Ctrl+Alt+Shift+G`：右侧 lazygit Git 看板

## 代码导航

这里有三层能力，需要分清：Neovim 语义跳转、WezTerm 终端文本跳转、引用/调用搜索。

### 在 Neovim 里语义跳转

快捷键：

- `gd`：跳到定义，LSP 挂上时优先走 LSP
- `gD`：跳到声明 / 原型，LSP 挂上时优先走 LSP
- `<leader>gd` / `<leader>gD`：同上，保留给习惯 leader 组合的人
- `gr`：查找引用
- `K`：查看悬停说明
- `<leader>rn`：重命名符号
- `<leader>ca`：代码动作

Neovim 当前配置会优先接内置 LSP：

- C/C++：`clangd`
- Python：按可执行文件优先级自动接 `basedpyright`、`pyright`、`pylsp`

如果当前 buffer 没有挂上 LSP，`gd` / `gD` 仍会回退到 [wezterm/scripts/jump-to-definition.ps1](wezterm/scripts/jump-to-definition.ps1) 这条共享跳转链：

- C/C++：调用 `clangd`，发送 LSP 的 `textDocument/definition` / `textDocument/declaration` 请求。项目最好提供 `compile_commands.json`，否则 `clangd` 只能按默认参数猜。
- Python：优先发现项目里的 `.venv`、`venv`、`env` 或当前 `VIRTUAL_ENV`，用对应解释器环境配合 `jedi` 解析定义。
- 其他语言或语义解析失败：回退到 `ctags`。

Python 项目如果要启用 LSP，建议安装 `basedpyright` 或 `pyright`。没有 LSP 时，再装 `jedi` 作为回退：

```bash
python -m pip install basedpyright
```

或：

```bash
python -m pip install pyright
```

如果只需要回退解析：

```bash
python -m pip install jedi
```

C/C++ 项目如果缺编译数据库，可以用 CMake 生成：

```bash
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

### 从终端跳到定义 / 声明

快捷键：

- `Ctrl+Alt+G`：跳到定义
- `Ctrl+Alt+Shift+D`：跳到声明 / 原型，找不到声明时会回退到可用匹配

使用方式：

1. 在终端输出、代码片段或文本中用鼠标选中函数名/符号名。
2. 按 `Ctrl+Alt+G`。
3. WezTerm 会调用 [wezterm/scripts/jump-to-definition.ps1](wezterm/scripts/jump-to-definition.ps1)。
4. 因为终端选中文本没有当前文件/光标位置，脚本会使用 `ctags` 缓存索引做兜底式查找。
5. 找到目标后，通过 [wezterm/scripts/open-in-nvim.ps1](wezterm/scripts/open-in-nvim.ps1) 在当前 WezTerm 窗口的新 Neovim 标签页中打开目标行。

这个入口适合“我在终端里看到一个函数名，想快速打开它的定义或声明”。它打开的是 Neovim，不会跳到 VS Code。它没有当前文件和光标位置，所以不等价于 Neovim buffer 内的 LSP 跳转。

配置文件是 [wezterm/symbol-jump.json](wezterm/symbol-jump.json)：

```json
{
  "providers": [
    {
      "type": "ctags",
      "name": "ctags",
      "languages": ["C", "C++", "Java", "Python", "Lua", "JavaScript", "TypeScript", "Go", "Rust", "C#", "CMake"],
      "rootMarkers": [".git", "compile_commands.json", "CMakeLists.txt", "pom.xml", "build.gradle", "settings.gradle", "pyproject.toml", "setup.py", "package.json", "go.mod", "Cargo.toml"]
    }
  ]
}
```

可以在这里增加语言或项目根目录标记。第一次跳转会生成缓存，缓存放在 `~/.wezterm-config/wezterm/symbol-jump-cache`。

如果项目代码变动很大但跳转位置不更新，可以删除 `~/.wezterm-config/wezterm/symbol-jump-cache` 后再次触发跳转，让脚本重新生成索引。

### Neovim tags 兜底跳转

Neovim 共享配置已经包含：

```vim
set tags=./tags;,tags
```

这表示 Neovim 会从当前目录向上查找 `tags` 文件。要启用 tags 跳转，需要在项目根目录生成 tags：

```bash
ctags -R --fields=+n --extras=+q -f tags .
```

也可以在 Neovim 里执行：

```vim
:TagsRefresh
```

或按 `<leader>tg`。默认 leader 是 `\`，也就是 `\tg`。

生成后，在 Neovim 中可以用：

- `Ctrl+]`：跳到光标下符号的定义
- `Ctrl+T`：跳回上一个位置
- `g]`：列出光标下符号的多个匹配，适合在声明和定义之间选择
- `:tag 符号名`：跳到指定符号
- `:tselect 符号名`：多个匹配时手动选择
- `:tags`：查看跳转栈

这个方式完全留在 Neovim 内部。声明和定义都在 tags 里时，`g]` 或 `:tselect 符号名` 可以手动选择要去声明还是定义。它是语义 provider 不可用时的备用方案。

### 查找函数调用 / 引用

当前已经有定义/声明的语义跳转入口，但还没有做“查找所有引用 / 调用层级”的完整 LSP 客户端。ctags 主要索引定义，不可靠地回答“哪里调用了这个函数”。

当前可用方式：

```bash
git grep -n "函数名"
```

如果系统安装了 ripgrep，可以用：

```bash
rg -n "函数名"
rg -n "函数名\s*\(" .
```

在 Neovim 里也可以用 quickfix 看搜索结果：

```vim
:vimgrep /函数名/gj **/*
:copen
```

如果以后要把这套终端环境继续升级，下一步是把“查找引用 / 调用层级”也接入 LSP，例如 C/C++ 的 `textDocument/references`，Python 的 Pyright/Jedi 引用查询。

## Neovim 编辑体验

仓库内 Neovim 配置位于 [wezterm/nvim/init.lua](wezterm/nvim/init.lua)。共享的兼容设置位于 [wezterm/nvim/shared.vim](wezterm/nvim/shared.vim)，旧的 [wezterm/vim/vimrc](wezterm/vim/vimrc) 只是兼容包装层。当前重点是轻量、稳定、开箱即用：

- 底部状态栏显示 `NORMAL` / `INSERT` / `REPLACE` / `VISUAL`
- INSERT 模式使用更明显的绿色提示
- 显示当前文件、文件类型、编码、行列位置
- 尝试显示当前类 / 函数上下文
- 左侧行号区和当前行号做了独立高亮
- 顶部路径栏已关闭，避免占用空间
- 内置 `lazy.nvim` 启动器，会按需拉起 `nvim-lspconfig`、`nvim-treesitter`、`fzf-lua`、`gitsigns.nvim`、`tokyonight.nvim`

`lazy.nvim` 本地仓库优先级：

- 如果设置了环境变量 `WEZTERM_LAZY_NVIM_PATH`，会优先使用这个目录下的 `lazy.nvim`
- 否则会检查 [wezterm/nvim](wezterm/nvim) 下的 `vendor/lazy.nvim`
- 只有本地仓库都不存在时，才会尝试在线 clone 到运行时目录

推荐的离线安装方式：

- 设置 `WEZTERM_NVIM_OFFLINE=1`，Neovim 将不再尝试拉取缺失插件
- `nvim-treesitter` 的 parser 自动安装默认关闭；只有设置 `WEZTERM_NVIM_AUTO_INSTALL_PARSERS=1` 才会尝试自动下载/更新 parser
- 把 `lazy.nvim` 放到 `wezterm/nvim/vendor/lazy.nvim`，或用 `WEZTERM_LAZY_NVIM_PATH` 指到已有本地仓库
- 把常用插件放到 `wezterm/nvim/vendor/plugins/` 下，目录名使用仓库名最后一段，例如 `nvim-lspconfig`、`nvim-treesitter`、`fzf-lua`、`nvim-web-devicons`、`gitsigns.nvim`、`tokyonight.nvim`
- 如果你想把插件放在别处，可以设置 `WEZTERM_NVIM_PLUGIN_ROOT` 指向那个本地插件目录
- `install.ps1` 会把这些 `vendor` 目录一起同步到运行时，所以更适合做整套离线包

注意：离线模式只解决插件仓库拉取问题；`clangd`、`basedpyright` / `pyright` / `pylsp`、`git` 以及 Treesitter parser 仍然需要你提前在本机准备好。如果你打开 `WEZTERM_NVIM_AUTO_INSTALL_PARSERS=1`，还需要本机已有 `tree-sitter` CLI、C 编译器、`curl` 和 `tar`。

常用按键：

- `Ctrl+S`：保存
- `Esc Esc`：清除搜索高亮
- `Ctrl+P`：使用 `fzf-lua` 查找文件
- `<leader>fg`：全文搜索

## Git 工作流

Git 相关默认优化：

- `GIT_EDITOR=nvim`
- `GIT_PAGER=less -R`
- `Ctrl+Alt+Shift+G`：右侧打开 lazygit

常用别名：

- `gs`：`git status -sb`
- `ga`：`git add`
- `gc`：`git commit`
- `gp`：`git push`
- `gl`：`git pull`
- `lg`：`lazygit`

## Shell 体验

Git Bash 启动脚本位于 [wezterm/shell/bashrc](wezterm/shell/bashrc)。

已启用：

- 大小写不敏感补全
- Tab 菜单补全
- `Shift+Tab` 反向补全
- 上下箭头按当前输入前缀搜索历史
- Starship prompt 和 completion
- 每次新 prompt 前绘制一条整行渐变分隔带

临时关闭渐变分隔带：

```bash
export WEZTERM_PROMPT_DIVIDER=0
```

重新打开终端后默认恢复开启。

工具包装：

- `cat`：使用 `bat --paging=never`
- `bat`：本地 bat
- `ls`：使用 eza 图标列表
- `ll`：详细列表、Git 状态、图标
- `tree`：eza tree，默认 3 层，可用 `TREE_LEVEL=5 tree` 调整
- `y`：Yazi

## SSH

安装后，`~/.ssh/config` 会 Include 仓库托管配置：

```sshconfig
Include ~/.wezterm-config/wezterm/ssh/config
```

默认 SSH 行为来自 [wezterm/ssh/config](wezterm/ssh/config)：

- keepalive：降低空闲断线概率
- ControlMaster：复用连接，后续 SSH/SCP/Git over SSH 更快
- ControlPersist：连接保持 10 分钟
- ControlPath：socket 放在 `~/.ssh/cm`
- `StrictHostKeyChecking accept-new`：第一次连接自动接受新主机指纹，已有指纹变化仍会报错
- `ForwardAgent no`：默认不开 agent 转发

辅助命令：

- `ssh-hosts`：列出 `~/.ssh/config` 里的主机别名
- `sshv`：等价于 `ssh -vvv`
- `ssh-clean`：清理连接复用 socket

## WezTerm 快捷键

基础操作：

- `Ctrl+Shift+C` / `Ctrl+Shift+V`：复制 / 粘贴
- `Ctrl+Insert` / `Shift+Insert`：复制 / 粘贴备用键
- `Ctrl+Shift+N`：新建窗口
- `Ctrl+Shift+L`：打开启动器
- `Ctrl+Shift+P`：打开命令面板
- `Ctrl+Shift+R`：重载配置
- `F11` / `Alt+Enter`：切换全屏
- `Ctrl+Alt+Y`：切换窗口置顶

搜索和选择：

- `Ctrl+Shift+F`：搜索当前终端内容
- `Ctrl+Shift+E`：快速选择路径、URL、哈希等文本
- `Ctrl+Shift+X`：进入复制模式
- `Ctrl+Shift+K`：清空滚动历史和当前屏幕
- `Shift+PageUp` / `Shift+PageDown`：按页滚动
- `Ctrl+Shift+Up` / `Ctrl+Shift+Down`：按行滚动

字号：

- `Ctrl+=` / `Ctrl+-`：放大 / 缩小字号
- `Ctrl+0`：重置字号

代码导航：

- `gd`：在 Neovim 内优先按 LSP 跳定义，没有 LSP 时回退共享跳转脚本
- `gD`：在 Neovim 内优先按 LSP 跳声明 / 原型，没有 LSP 时回退共享跳转脚本
- `Ctrl+Alt+G`：终端选中符号后按 `ctags` 兜底索引在 Neovim 新标签页跳到定义
- `Ctrl+Alt+Shift+D`：终端选中符号后按 `ctags` 兜底索引在 Neovim 新标签页跳到声明 / 原型

## 目录结构

```text
.
├── .wezterm.lua                         # 用户目录 loader 的源文件
├── install.ps1                          # 安装 / 同步脚本
├── README.md                            # 当前文档
└── wezterm
    ├── wezterm.lua                      # WezTerm 主配置
    ├── shell/bashrc                     # Git Bash 初始化
    ├── nvim/                            # Neovim 配置
    ├── vim/vimrc                        # 兼容层，复用共享编辑配置
    ├── yazi/                            # Yazi 配置和主题
    ├── scripts/                         # 打开 Neovim、符号跳转、置顶等脚本
    ├── ssh/config                       # SSH 默认配置
    ├── starship.toml                    # Prompt 配置
    ├── symbol-jump.json                 # 符号跳转配置
    └── tools/windows/                   # bat/eza/yazi/lazygit 等本地工具
```

## 配置入口

常改文件：

- [wezterm/wezterm.lua](wezterm/wezterm.lua)：窗口、快捷键、分窗、标签页、文件树、lazygit、符号跳转入口
- [wezterm/shell/bashrc](wezterm/shell/bashrc)：Git Bash 行为、别名、补全、prompt 分隔带、`nvim 文件` / `vim 文件` 打开策略
- [wezterm/nvim/init.lua](wezterm/nvim/init.lua)：Neovim 主配置和内置插件/LSP 入口
- [wezterm/nvim/shared.vim](wezterm/nvim/shared.vim)：Vim / Neovim 共享编辑设置
- [wezterm/vim/vimrc](wezterm/vim/vimrc)：兼容层
- [wezterm/yazi/yazi.toml](wezterm/yazi/yazi.toml)：文件打开规则
- [wezterm/yazi/init.lua](wezterm/yazi/init.lua)：Yazi 鼠标点击行为
- [wezterm/scripts/open-in-nvim.ps1](wezterm/scripts/open-in-nvim.ps1)：Yazi / Bash 打开 Neovim 的 Windows 侧入口
- [wezterm/scripts/open-in-vim.ps1](wezterm/scripts/open-in-vim.ps1)：兼容入口，内部转发到 Neovim
- [wezterm/scripts/jump-to-definition.ps1](wezterm/scripts/jump-to-definition.ps1)：统一符号跳转入口，语义优先，`ctags` 兜底
- [wezterm/scripts/resolve-symbol.py](wezterm/scripts/resolve-symbol.py)：`clangd` / Python `jedi` 语义解析器
- [wezterm/symbol-jump.json](wezterm/symbol-jump.json)：符号索引语言和项目根标记
- [wezterm/ssh/config](wezterm/ssh/config)：SSH 默认优化

修改仓库配置后，运行安装脚本同步到 `%USERPROFILE%\.wezterm-config`：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

如果只改了 Bash 配置，也可以在当前 shell 里临时加载：

```bash
source ~/.wezterm-config/wezterm/shell/bashrc
```
