# Offline Assets

This folder keeps the Windows installers and portable archives that match the
current WezTerm + Git Bash + Neovim workflow.

- `WezTerm-...-setup.exe`: terminal emulator
- `Git-...-64-bit.exe`: Git for Windows and Git Bash
- `nvim-win64.msi`: Neovim
- `starship-...msi`: shell prompt
- `tree-sitter-windows-x64.gz`: optional `tree-sitter` CLI
- `bat-...zip`: syntax-highlighting pager
- `eza-...zip`: modern `ls` replacement
- `lazygit_...zip`: Git dashboard
- `yazi-...zip`: file manager

The JetBrains Mono Nerd Font files are already vendored under [wezterm/fonts/JetBrainsMonoNerdFont](c:/Users/qwer/Desktop/wezterm-config/wezterm/fonts/JetBrainsMonoNerdFont), so the oversized archive is intentionally not tracked in `downloads/`.

`clangd` is intentionally not bundled; install it later if you want C/C++ LSP.
`tree-sitter` is optional. The repo does not auto-install parsers unless
`WEZTERM_NVIM_AUTO_INSTALL_PARSERS=1` is set and the required toolchain is
available on the machine.