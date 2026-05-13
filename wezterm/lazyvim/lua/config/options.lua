-- Options are automatically loaded before lazy.nvim startup

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.winbar = "%{%v:lua.require('config.context').render()%}"