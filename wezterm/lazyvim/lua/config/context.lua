local M = {}

local excluded_buftypes = {
  help = true,
  nofile = true,
  prompt = true,
  quickfix = true,
  terminal = true,
}

local excluded_filetypes = {
  checkhealth = true,
  lazy = true,
  mason = true,
  noice = true,
  qf = true,
}

local cache = {}

local fallback_patterns = {
  lua = {
    { label = "Function", pattern = "^%s*local%s+function%s+([%w_%.:]+)" },
    { label = "Function", pattern = "^%s*function%s+([%w_%.:]+)" },
  },
  python = {
    { label = "Class", pattern = "^%s*class%s+([%w_%.]+)" },
    { label = "Function", pattern = "^%s*def%s+([%w_%.]+)" },
  },
}

local function buf_name(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end

  return vim.fn.fnamemodify(name, ":t")
end

local function node_text(node, bufnr)
  local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
  if not ok or type(text) ~= "string" then
    return ""
  end

  text = text:gsub("%s+", " ")
  if #text > 40 then
    text = text:sub(1, 37) .. "..."
  end

  return text
end

local function classify(node_type)
  if node_type:find("method", 1, true) then
    return "Method"
  end
  if node_type:find("function", 1, true) then
    return "Function"
  end
  if node_type:find("class", 1, true) then
    return "Class"
  end
  if node_type:find("interface", 1, true) then
    return "Interface"
  end
  if node_type:find("struct", 1, true) then
    return "Struct"
  end
  if node_type:find("enum", 1, true) then
    return "Enum"
  end
  if node_type:find("module", 1, true) or node_type:find("namespace", 1, true) then
    return "Module"
  end

  return nil
end

local function extract_name(node, bufnr, depth)
  depth = depth or 0
  if depth > 6 then
    return ""
  end

  local named_fields = { "name", "declarator", "body", "subject", "label" }
  for _, field in ipairs(named_fields) do
    local field_nodes = node:field(field)
    if field_nodes and #field_nodes > 0 then
      local text = node_text(field_nodes[1], bufnr)
      if text ~= "" then
        return text
      end
    end
  end

  for child in node:iter_children() do
    if child:named() then
      local child_type = child:type()
      if child_type == "identifier"
        or child_type == "name"
        or child_type == "field_identifier"
        or child_type == "property_identifier"
        or child_type == "type_identifier"
      then
        local text = node_text(child, bufnr)
        if text ~= "" then
          return text
        end
      end

      if child_type:find("declarator", 1, true)
        or child_type:find("definition", 1, true)
        or child_type:find("declaration", 1, true)
      then
        local text = extract_name(child, bufnr, depth + 1)
        if text ~= "" then
          return text
        end
      end
    end
  end

  return ""
end

local function current_context(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return ""
  end

  local trees = parser:parse()
  local tree = trees and trees[1]
  if not tree then
    return ""
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local node = tree:root():named_descendant_for_range(row, col, row, col)
  if not node then
    return ""
  end

  local parts = {}
  while node do
    local label = classify(node:type())
    if label then
      local name = extract_name(node, bufnr)
      if name ~= "" then
        table.insert(parts, 1, string.format("%s %s", label, name))
      end
    end
    node = node:parent()
  end

  return table.concat(parts, " > ")
end

local function fallback_context(bufnr)
  local patterns = fallback_patterns[vim.bo[bufnr].filetype]
  if not patterns then
    return ""
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, cursor[1], false)
  local parts = {}
  local seen = {}

  for index = #lines, 1, -1 do
    local line = lines[index]
    for _, entry in ipairs(patterns) do
      if not seen[entry.label] then
        local name = line:match(entry.pattern)
        if name and name ~= "" then
          table.insert(parts, 1, string.format("%s %s", entry.label, name))
          seen[entry.label] = true
        end
      end
    end
  end

  return table.concat(parts, " > ")
end

function M.render()
  local bufnr = vim.api.nvim_get_current_buf()
  if excluded_buftypes[vim.bo[bufnr].buftype] or excluded_filetypes[vim.bo[bufnr].filetype] then
    return ""
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local tick = vim.b[bufnr].changedtick or 0
  local cached = cache[bufnr]
  if cached and cached.row == cursor[1] and cached.col == cursor[2] and cached.tick == tick then
    return cached.value
  end

  local file_part = buf_name(bufnr)
  local context = current_context(bufnr)
  if context == "" then
    context = fallback_context(bufnr)
  end
  local value = file_part
  if context ~= "" then
    value = string.format("%s :: %s", file_part, context)
  end

  cache[bufnr] = {
    col = cursor[2],
    row = cursor[1],
    tick = tick,
    value = value,
  }

  return value
end

return M