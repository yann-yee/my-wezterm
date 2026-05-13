local uv = vim.uv or vim.loop

local M = {}

function M.normalize(path)
  return path and path:gsub("\\", "/") or nil
end

function M.tools_root()
  local tools_root = M.normalize(vim.env.WEZTERM_TOOLS_ROOT_WIN or vim.env.WEZTERM_TOOLS_ROOT)
  if not tools_root and vim.env.USERPROFILE then
    tools_root = M.normalize(vim.env.USERPROFILE .. "\\Desktop\\WezTerm\\Tools")
  end

  return tools_root
end

function M.data_root()
  return M.tools_root() and (M.tools_root() .. "/nvim-data") or M.normalize(vim.fn.stdpath("data"))
end

function M.lazy_root()
  return M.data_root() .. "/lazy"
end

function M.lockfile()
  return M.data_root() .. "/lazy-lock.json"
end

function M.mason_root()
  return M.data_root() .. "/mason"
end

function M.site_root()
  return M.data_root() .. "/site"
end

function M.parser_root()
  return M.site_root() .. "/parser"
end

function M.ensure_dir(path)
  if path and not uv.fs_stat(path) then
    vim.fn.mkdir(path, "p")
  end
end

function M.ensure_data_dirs()
  M.ensure_dir(M.data_root())
  M.ensure_dir(M.lazy_root())
  M.ensure_dir(M.mason_root())
  M.ensure_dir(M.site_root())
  M.ensure_dir(M.parser_root())

  local site_root = M.site_root()
  if not string.find(vim.o.runtimepath, site_root, 1, true) then
    vim.opt.runtimepath:append(site_root)
  end
end

return M
