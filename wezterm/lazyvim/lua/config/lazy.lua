local uv = vim.uv or vim.loop
local paths = require("config.portable_paths")

local function existing_path(candidates)
  for _, candidate in ipairs(candidates) do
    if candidate and uv.fs_stat(candidate) then
      return candidate
    end
  end

  return nil
end

paths.ensure_data_dirs()

local lazypath = existing_path({
  paths.tools_root() and (paths.tools_root() .. "/lazy.nvim") or nil,
  paths.data_root() .. "/lazy/lazy.nvim",
  vim.fn.stdpath("data") .. "/lazy/lazy.nvim",
}) or (paths.data_root() .. "/lazy/lazy.nvim")

if not uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  root = paths.lazy_root(),
  lockfile = paths.lockfile(),
  defaults = {
    lazy = false,
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true,
    notify = false,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})