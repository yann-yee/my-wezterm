vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local function normalize_root(path)
  if not path or path == '' then
    local home = vim.loop.os_homedir() or vim.env.USERPROFILE or ''
    return home .. '/.wezterm-config/wezterm'
  end

  local drive, rest = path:match('^/([A-Za-z])/(.*)$')
  if drive then
    return string.format('%s:/%s', drive:upper(), rest)
  end

  return (path:gsub('\\', '/'))
end

local config_root = normalize_root(vim.env.WEZTERM_CONFIG_ROOT)
vim.g.wezterm_editor_config_root = config_root

vim.opt.runtimepath:append(config_root .. '/nvim')
vim.cmd('source ' .. vim.fn.fnameescape(config_root .. '/nvim/shared.vim'))

vim.opt.completeopt = { 'menuone', 'noselect', 'popup' }
vim.opt.shortmess:append('I')
vim.opt.termguicolors = true

local function executable(name)
  return vim.fn.executable(name) == 1
end

local function env_truthy(name)
  local value = vim.env[name]
  if not value or value == '' then
    return false
  end

  value = value:lower()
  return value == '1' or value == 'true' or value == 'yes' or value == 'on'
end

local function notify_warn(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN)
  end)
end

local warned_messages = {}

local function notify_warn_once(message)
  if warned_messages[message] then
    return
  end

  warned_messages[message] = true
  notify_warn(message)
end

local function safe_require(module_name, plugin_name)
  local ok, module = pcall(require, module_name)
  if ok then
    return module
  end

  local source = plugin_name or module_name
  notify_warn_once('Skipped ' .. source .. ' config because module "' .. module_name .. '" is unavailable.')
  return nil
end

local function try_require(module_name)
  local ok, module = pcall(require, module_name)
  if ok then
    return module
  end

  return nil
end

local offline_mode = env_truthy('WEZTERM_NVIM_OFFLINE')
local auto_install_parsers = env_truthy('WEZTERM_NVIM_AUTO_INSTALL_PARSERS')

local function lazy_entrypoint(lazypath)
  return lazypath .. '/lua/lazy/init.lua'
end

local function local_plugin_root(config_root)
  if vim.env.WEZTERM_NVIM_PLUGIN_ROOT and vim.env.WEZTERM_NVIM_PLUGIN_ROOT ~= '' then
    return normalize_root(vim.env.WEZTERM_NVIM_PLUGIN_ROOT)
  end

  return config_root .. '/nvim/vendor/plugins'
end

local function plugin_dir_name(repo)
  return repo:match('/([^/]+)$') or repo
end

local function plugin_dir_path(plugin_root, repo)
  local candidate = plugin_root .. '/' .. plugin_dir_name(repo)
  if vim.loop.fs_stat(candidate) then
    return candidate
  end

  return nil
end

local function find_local_lazy(config_root)
  local candidates = {}

  if vim.env.WEZTERM_LAZY_NVIM_PATH and vim.env.WEZTERM_LAZY_NVIM_PATH ~= '' then
    table.insert(candidates, normalize_root(vim.env.WEZTERM_LAZY_NVIM_PATH))
  end

  table.insert(candidates, config_root .. '/nvim/vendor/lazy.nvim')

  for _, candidate in ipairs(candidates) do
    if vim.loop.fs_stat(lazy_entrypoint(candidate)) then
      return candidate
    end
  end

  return nil
end

local function install_lazy(lazypath)
  local entrypoint = lazy_entrypoint(lazypath)
  if vim.loop.fs_stat(entrypoint) then
    return true
  end

  if vim.loop.fs_stat(lazypath) then
    vim.fn.delete(lazypath, 'rf')
  end

  if executable('git') then
    local result = vim.fn.system({
      'git',
      'clone',
      '--filter=blob:none',
      'https://github.com/folke/lazy.nvim.git',
      '--branch=stable',
      lazypath,
    })
    if vim.v.shell_error == 0 and vim.loop.fs_stat(entrypoint) then
      return true
    end
    notify_warn('Failed to install lazy.nvim: ' .. result)
  else
    notify_warn('git not found; Neovim plugins were not bootstrapped.')
  end
  return false
end

local lazypath = config_root .. '/nvim/lazy.nvim'
local plugin_root = local_plugin_root(config_root)
local lazy = nil
local function load_lazy(lazy_root)
  vim.opt.rtp:prepend(lazy_root)
  local ok, lazy_module = pcall(require, 'lazy')
  if ok then
    return lazy_module
  else
    notify_warn('Failed to load lazy.nvim: ' .. lazy_module)
  end

  return nil
end

local local_lazy_path = find_local_lazy(config_root)
if local_lazy_path then
  lazy = load_lazy(local_lazy_path)
elseif offline_mode then
  notify_warn('Offline mode is enabled and lazy.nvim was not found locally. Set WEZTERM_LAZY_NVIM_PATH or place it under nvim/vendor/lazy.nvim.')
elseif install_lazy(lazypath) then
  lazy = load_lazy(lazypath)
end

if lazy then
  local skipped_plugins = {}

  local function mark_skipped(repo)
    skipped_plugins[repo] = true
  end

  local function plugin_spec(repo, spec)
    spec = spec or {}

    local local_path = plugin_dir_path(plugin_root, repo)
    if local_path then
      spec.dir = local_path
      spec.name = spec.name or plugin_dir_name(repo)
      return spec
    end

    if offline_mode then
      mark_skipped(repo)
      return nil
    end

    spec[1] = repo
    return spec
  end

  local function dependency_specs(repos)
    local dependencies = {}

    for _, repo in ipairs(repos) do
      local dependency = plugin_spec(repo)
      if dependency then
        table.insert(dependencies, dependency)
      end
    end

    if #dependencies == 0 then
      return nil
    end

    return dependencies
  end

  local specs = {}

  local function add_spec(repo, spec)
    local plugin = plugin_spec(repo, spec)
    if plugin then
      table.insert(specs, plugin)
    end
  end

  add_spec('neovim/nvim-lspconfig', {
      config = function()
        local lspconfig = safe_require('lspconfig', 'nvim-lspconfig')
        if not lspconfig then
          return
        end

        local capabilities = vim.lsp.protocol.make_client_capabilities()

        local on_attach = function(_, bufnr)
          local opts = { buffer = bufnr, silent = true }
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        end

        if executable('clangd') then
          lspconfig.clangd.setup({
            capabilities = capabilities,
            on_attach = on_attach,
          })
        end

        local python_server = nil
        if executable('basedpyright-langserver') then
          python_server = 'basedpyright'
        elseif executable('pyright-langserver') then
          python_server = 'pyright'
        elseif executable('pylsp') then
          python_server = 'pylsp'
        end

        if python_server and lspconfig[python_server] then
          lspconfig[python_server].setup({
            capabilities = capabilities,
            on_attach = on_attach,
          })
        end
      end,
    })

  add_spec('nvim-treesitter/nvim-treesitter', {
      lazy = false,
      build = auto_install_parsers and not offline_mode and ':TSUpdate' or nil,
      config = function()
        local desired_parsers = { 'bash', 'c', 'cpp', 'lua', 'markdown', 'python', 'vim', 'vimdoc' }

        local legacy_configs = try_require('nvim-treesitter.configs')
        if legacy_configs then
          legacy_configs.setup({
            ensure_installed = auto_install_parsers and desired_parsers or nil,
            auto_install = auto_install_parsers,
            highlight = { enable = true },
            indent = { enable = true },
          })
          return
        end

        local treesitter = safe_require('nvim-treesitter', 'nvim-treesitter')
        if not treesitter then
          return
        end

        treesitter.setup({})

        local group = vim.api.nvim_create_augroup('WeztermTreesitter', { clear = true })
        vim.api.nvim_create_autocmd('FileType', {
          group = group,
          callback = function(args)
            if not (vim.treesitter and vim.treesitter.start) then
              return
            end

            local ok = pcall(vim.treesitter.start, args.buf)
            if ok then
              vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end,
        })

        if offline_mode or not auto_install_parsers then
          return
        end

        local installed = {}
        for _, parser in ipairs(treesitter.get_installed()) do
          installed[parser] = true
        end

        local missing = {}
        for _, parser in ipairs(desired_parsers) do
          if not installed[parser] then
            table.insert(missing, parser)
          end
        end

        if #missing > 0 then
          local ok, err = pcall(function()
            treesitter.install(missing)
          end)
          if not ok then
            notify_warn_once('Failed to schedule nvim-treesitter parser install: ' .. tostring(err))
          end
        end
      end,
    })

  add_spec('ibhagwan/fzf-lua', {
      dependencies = dependency_specs({ 'nvim-tree/nvim-web-devicons' }),
      config = function()
        local fzf_lua = safe_require('fzf-lua', 'fzf-lua')
        if not fzf_lua then
          return
        end

        fzf_lua.setup({
          winopts = {
            height = 0.85,
            width = 0.9,
            preview = { layout = 'vertical' },
          },
        })
        vim.keymap.set('n', '<C-p>', function()
          fzf_lua.files()
        end, { silent = true })
        vim.keymap.set('n', '<leader>fg', function()
          fzf_lua.live_grep()
        end, { silent = true })
      end,
    })

  add_spec('lewis6991/gitsigns.nvim', {
      config = function()
        local gitsigns = safe_require('gitsigns', 'gitsigns.nvim')
        if not gitsigns then
          return
        end

        gitsigns.setup()
      end,
    })

  add_spec('folke/tokyonight.nvim', {
      lazy = false,
      priority = 1000,
      config = function()
        local ok = pcall(vim.cmd.colorscheme, 'tokyonight-moon')
        if not ok then
          notify_warn_once('Skipped tokyonight.nvim config because the colorscheme is unavailable.')
        end
      end,
    })

  if offline_mode then
    local missing = {}
    for repo, skipped in pairs(skipped_plugins) do
      if skipped then
        table.insert(missing, repo)
      end
    end

    table.sort(missing)
    if #missing > 0 then
      notify_warn('Offline mode skipped missing plugins: ' .. table.concat(missing, ', ') .. '. Clone them into ' .. plugin_root .. ' or set WEZTERM_NVIM_PLUGIN_ROOT.')
    end
  end

  lazy.setup(specs, {
    install = { missing = not offline_mode },
    checker = { enabled = false },
    change_detection = { notify = false },
  })
else
  vim.cmd('colorscheme default')
end

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    local opts = { buffer = args.buf, silent = true }
    if client.server_capabilities.definitionProvider then
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    end
    if client.server_capabilities.declarationProvider then
      vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    end
  end,
})

vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    vim.cmd('highlight StatusLine guibg=#2F3549 guifg=#C0CAF5')
    vim.cmd('highlight StatusLineNC guibg=#1A1B26 guifg=#565F89')
    vim.cmd('highlight Normal guibg=#1A1B26 guifg=#C0CAF5')
    vim.cmd('highlight NonText guibg=#1A1B26 guifg=#565F89')
    vim.cmd('highlight EndOfBuffer guibg=#1A1B26 guifg=#565F89')
    vim.cmd('highlight LineNr guibg=#202436 guifg=#D7A65F')
    vim.cmd('highlight CursorLineNr guibg=#2F3549 guifg=#C0CAF5 gui=bold')
    vim.cmd('highlight SignColumn guibg=#202436 guifg=#565F89')
    vim.cmd('highlight FoldColumn guibg=#202436 guifg=#565F89')
    vim.cmd('highlight CursorLine guibg=#24283B')
    vim.cmd('highlight User1 guifg=#7DCFFF guibg=#2F3549 gui=bold')
    vim.cmd('highlight User2 guifg=#E0AF68 guibg=#2F3549 gui=bold')
    vim.cmd('highlight User3 guifg=#9ECE6A guibg=#2F3549')
    vim.cmd('highlight User6 guifg=#1A1B26 guibg=#7AA2F7 gui=bold')
  end,
})

vim.cmd('doautocmd ColorScheme')
