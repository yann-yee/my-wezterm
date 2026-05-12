local wezterm = require("wezterm")

local config = wezterm.config_builder and wezterm.config_builder() or {}
local act = wezterm.action

local home = os.getenv("USERPROFILE") or wezterm.home_dir or ""
local config_root = home .. "\\.wezterm-config\\wezterm"
local git_bash = "C:\\Program Files\\Git\\bin\\bash.exe"
local bash_rc = config_root .. "\\shell\\bashrc"
local yazi_exe = config_root .. "\\tools\\windows\\yazi\\yazi-x86_64-pc-windows-msvc\\yazi.exe"
local lazygit_exe = config_root .. "\\tools\\windows\\lazygit\\lazygit.exe"
local jump_script = config_root .. "\\scripts\\jump-to-definition.ps1"

local function uri_to_path(uri)
  local path = uri.file_path or tostring(uri or "")
  path = path:gsub("^file://", "")
  path = path:gsub("%%20", " ")
  path = path:gsub("^/([A-Za-z]):", "%1:")
  path = path:gsub("/", "\\")
  return path
end

local function tab_title(tab_info)
  local title = tab_info.tab_title
  if title and #title > 0 then
    return title
  end

  local pane = tab_info.active_pane
  local process_name = pane.foreground_process_name or pane.title or ""
  if #process_name > 0 then
    return process_name:match("[^/\\]+$") or process_name
  end

  return pane.title
end

local function jump_to_symbol(window, pane, target)
  local symbol = window:get_selection_text_for_pane(pane) or ""
  symbol = symbol:gsub("^%s+", ""):gsub("%s+$", "")
  symbol = symbol:match("([%w_][%w_%.:]*)") or ""

  if #symbol == 0 then
    window:toast_notification("WezTerm", "先选中一个函数或符号", nil, 2000)
    return
  end

  local cwd = pane:get_current_working_dir()
  local root = uri_to_path(cwd)

  local success, _stdout, stderr = wezterm.run_child_process({
    "powershell.exe",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    jump_script,
    "-Root",
    root,
    "-Symbol",
    symbol,
    "-Target",
    target,
  })

  if not success then
    window:toast_notification("WezTerm", stderr or ("未找到符号: " .. symbol), nil, 3000)
  end
end

local function jump_to_definition(window, pane)
  jump_to_symbol(window, pane, "Definition")
end

local function jump_to_declaration(window, pane)
  jump_to_symbol(window, pane, "Declaration")
end

local function toggle_tree_pane(window, pane)
  local process_name = pane:get_foreground_process_name() or ""
  process_name = process_name:lower()

  if process_name:match("yazi%.exe$") or process_name:match("yazi$") then
    window:perform_action(act.CloseCurrentPane({ confirm = false }), pane)
    return
  end

  local cwd = pane:get_current_working_dir()
  local args = { yazi_exe }
  if cwd and cwd.file_path then
    args[#args + 1] = uri_to_path(cwd)
  end

  window:perform_action(
    act.SplitPane({
      direction = "Left",
      size = { Percent = 30 },
      command = { args = args },
    }),
    pane
  )
end

wezterm.on("format-tab-title", function(tab_info, _tabs, _panes, _config, _hover, max_width)
  local title = wezterm.truncate_right(tab_title(tab_info), math.max(16, max_width - 8))
  local index = tostring(tab_info.tab_index + 1)
  local edge = tab_info.is_active and "#7AA2F7" or "#3B4261"
  local bg = tab_info.is_active and "#24283B" or "#1A1B26"
  local fg = tab_info.is_active and "#C0CAF5" or "#8C96B8"

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = edge } },
    { Text = " " .. index .. " " },
    { Foreground = { Color = fg } },
    { Text = title .. " " },
  }
end)

wezterm.on("update-right-status", function(window, pane)
  local cwd = pane:get_current_working_dir()
  local cwd_text = ""

  if cwd then
    cwd_text = cwd.file_path or tostring(cwd)
    cwd_text = cwd_text:gsub("^file://", "")
    cwd_text = cwd_text:gsub("%%20", " ")
    cwd_text = cwd_text:gsub("^/([A-Za-z]):", "%1:")
    cwd_text = cwd_text:gsub("\\", "/")
    cwd_text = cwd_text:match("([^/]+)$") or cwd_text
  end

  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#565F89" } },
    { Text = " " .. cwd_text .. " " },
  }))
end)

config.default_prog = {
  git_bash,
  "--noprofile",
  "--rcfile",
  bash_rc,
  "-i",
}

config.launch_menu = {
  {
    label = "Git Bash",
    args = {
      git_bash,
      "--noprofile",
      "--rcfile",
      bash_rc,
      "-i",
    },
  },
  {
    label = "Git Dashboard (lazygit)",
    args = { lazygit_exe },
  },
  {
    label = "PowerShell",
    args = { "powershell.exe", "-NoLogo" },
  },
  {
    label = "Command Prompt",
    args = { "cmd.exe" },
  },
}

config.set_environment_variables = {
  WEZTERM_CONFIG_ROOT = config_root,
  YAZI_CONFIG_HOME = config_root .. "\\yazi",
  YAZI_FILE_ONE = "C:\\Program Files\\Git\\usr\\bin\\file.exe",
  TERM = "xterm-256color",
  COLORTERM = "truecolor",
}

config.default_cwd = home
config.color_scheme = "Tokyo Night Moon"
config.initial_cols = 120
config.initial_rows = 34
config.font_dirs = {
  config_root .. "\\fonts",
}
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font Mono",
  "JetBrainsMono Nerd Font",
  "JetBrainsMonoNL Nerd Font Mono",
  "JetBrainsMonoNL Nerd Font",
  "Cascadia Code",
  "Consolas",
})
config.font_size = 11.0
config.line_height = 1.08
config.window_padding = {
  left = 6,
  right = 6,
  top = 1,
  bottom = 4,
}
config.scrollback_lines = 50000
config.adjust_window_size_when_changing_font_size = false
config.default_cursor_style = "BlinkingBar"
config.window_background_opacity = 0.94
config.text_background_opacity = 1.0
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.72,
}
config.pane_focus_follows_mouse = true
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.show_tabs_in_tab_bar = true
config.show_new_tab_button_in_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
config.tab_max_width = 48
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.integrated_title_buttons = { "Hide", "Maximize", "Close" }
config.integrated_title_button_alignment = "Right"
config.integrated_title_button_style = "Windows"
config.integrated_title_button_color = "Auto"
config.window_frame = {
  font_size = 9,
  font = wezterm.font({ family = "JetBrainsMono Nerd Font Mono", weight = "Medium" }),
  active_titlebar_bg = "#1A1B26",
  inactive_titlebar_bg = "#16161E",
}
config.colors = {
  foreground = "#C0CAF5",
  background = "#1A1B26",
  cursor_bg = "#7AA2F7",
  cursor_fg = "#1A1B26",
  cursor_border = "#7AA2F7",
  selection_fg = "#C0CAF5",
  selection_bg = "#33467C",
  scrollbar_thumb = "#3B4261",
  split = "#3B4261",
  tab_bar = {
    background = "#1A1B26",
    active_tab = {
      bg_color = "#2F3549",
      fg_color = "#C0CAF5",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = "#1A1B26",
      fg_color = "#7AA2F7",
    },
    inactive_tab_hover = {
      bg_color = "#24283B",
      fg_color = "#C0CAF5",
    },
  },
}
config.command_palette_bg_color = "#1A1B26"
config.command_palette_fg_color = "#C0CAF5"
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"
config.check_for_updates = false

local topmost_script = config_root .. "\\scripts\\toggle-topmost.ps1"

config.keys = {
  {
    key = "c",
    mods = "CTRL|SHIFT",
    action = act.CopyTo("Clipboard"),
  },
  {
    key = "v",
    mods = "CTRL|SHIFT",
    action = act.PasteFrom("Clipboard"),
  },
  {
    key = "Insert",
    mods = "CTRL",
    action = act.CopyTo("Clipboard"),
  },
  {
    key = "Insert",
    mods = "SHIFT",
    action = act.PasteFrom("Clipboard"),
  },
  {
    key = "r",
    mods = "CTRL|SHIFT",
    action = act.ReloadConfiguration,
  },
  {
    key = "F11",
    mods = "NONE",
    action = act.ToggleFullScreen,
  },
  {
    key = "Enter",
    mods = "ALT",
    action = act.ToggleFullScreen,
  },
  {
    key = "p",
    mods = "CTRL|SHIFT",
    action = act.ActivateCommandPalette,
  },
  {
    key = "l",
    mods = "CTRL|SHIFT",
    action = act.ShowLauncher,
  },
  {
    key = "f",
    mods = "CTRL|SHIFT",
    action = act.Search({ CaseInSensitiveString = "" }),
  },
  {
    key = "e",
    mods = "CTRL|SHIFT",
    action = act.QuickSelect,
  },
  {
    key = "g",
    mods = "CTRL|ALT",
    action = act.QuickSelectArgs({
      label = "open symbol location",
      patterns = {
        "[A-Za-z_][A-Za-z0-9_%.:]*",
      },
      action = wezterm.action_callback(jump_to_definition),
    }),
  },
  {
    key = "d",
    mods = "CTRL|ALT|SHIFT",
    action = act.QuickSelectArgs({
      label = "open symbol declaration",
      patterns = {
        "[A-Za-z_][A-Za-z0-9_%.:]*",
      },
      action = wezterm.action_callback(jump_to_declaration),
    }),
  },
  {
    key = "x",
    mods = "CTRL|SHIFT",
    action = act.ActivateCopyMode,
  },
  {
    key = "k",
    mods = "CTRL|SHIFT",
    action = act.ClearScrollback("ScrollbackAndViewport"),
  },
  {
    key = "n",
    mods = "CTRL|SHIFT",
    action = act.SpawnWindow,
  },
  {
    key = "t",
    mods = "CTRL|SHIFT",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  {
    key = "w",
    mods = "CTRL|SHIFT",
    action = act.CloseCurrentTab({ confirm = false }),
  },
  {
    key = "Tab",
    mods = "CTRL",
    action = act.ActivateTabRelative(1),
  },
  {
    key = "Tab",
    mods = "CTRL|SHIFT",
    action = act.ActivateTabRelative(-1),
  },
  {
    key = "LeftArrow",
    mods = "CTRL|SHIFT",
    action = act.MoveTabRelative(-1),
  },
  {
    key = "RightArrow",
    mods = "CTRL|SHIFT",
    action = act.MoveTabRelative(1),
  },
  {
    key = "PageUp",
    mods = "SHIFT",
    action = act.ScrollByPage(-1),
  },
  {
    key = "PageDown",
    mods = "SHIFT",
    action = act.ScrollByPage(1),
  },
  {
    key = "UpArrow",
    mods = "CTRL|SHIFT",
    action = act.ScrollByLine(-3),
  },
  {
    key = "DownArrow",
    mods = "CTRL|SHIFT",
    action = act.ScrollByLine(3),
  },
  {
    key = "=",
    mods = "CTRL",
    action = act.IncreaseFontSize,
  },
  {
    key = "+",
    mods = "CTRL|SHIFT",
    action = act.IncreaseFontSize,
  },
  {
    key = "-",
    mods = "CTRL",
    action = act.DecreaseFontSize,
  },
  {
    key = "0",
    mods = "CTRL",
    action = act.ResetFontSize,
  },
  {
    key = "t",
    mods = "CTRL|ALT",
    action = wezterm.action_callback(toggle_tree_pane),
  },
  {
    key = "g",
    mods = "CTRL|ALT|SHIFT",
    action = act.SplitPane({
      direction = "Right",
      size = { Percent = 36 },
      command = { args = { lazygit_exe } },
    }),
  },
  {
    key = "y",
    mods = "CTRL|ALT",
    action = wezterm.action_callback(function(window, _pane)
      local success, _stdout, stderr = wezterm.run_child_process({
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        topmost_script,
      })

      if success then
        window:toast_notification("WezTerm", "已切换置顶", nil, 2000)
      else
        window:toast_notification("WezTerm", stderr or "置顶切换失败", nil, 3000)
      end
    end),
  },
  {
    key = "Enter",
    mods = "CTRL|ALT",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "\\",
    mods = "CTRL|ALT",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "x",
    mods = "CTRL|ALT",
    action = act.CloseCurrentPane({ confirm = false }),
  },
  {
    key = "z",
    mods = "CTRL|ALT",
    action = act.TogglePaneZoomState,
  },
  {
    key = "h",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Left"),
  },
  {
    key = "j",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Down"),
  },
  {
    key = "k",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Up"),
  },
  {
    key = "l",
    mods = "CTRL|ALT",
    action = act.ActivatePaneDirection("Right"),
  },
  {
    key = "LeftArrow",
    mods = "CTRL|ALT|SHIFT",
    action = act.AdjustPaneSize({ "Left", 5 }),
  },
  {
    key = "RightArrow",
    mods = "CTRL|ALT|SHIFT",
    action = act.AdjustPaneSize({ "Right", 5 }),
  },
  {
    key = "UpArrow",
    mods = "CTRL|ALT|SHIFT",
    action = act.AdjustPaneSize({ "Up", 3 }),
  },
  {
    key = "DownArrow",
    mods = "CTRL|ALT|SHIFT",
    action = act.AdjustPaneSize({ "Down", 3 }),
  },
  {
    key = ",",
    mods = "CTRL|ALT",
    action = act.PromptInputLine({
      description = "Rename tab",
      action = wezterm.action_callback(function(window, _pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },
  {
    key = "1",
    mods = "ALT",
    action = act.ActivateTab(0),
  },
  {
    key = "2",
    mods = "ALT",
    action = act.ActivateTab(1),
  },
  {
    key = "3",
    mods = "ALT",
    action = act.ActivateTab(2),
  },
  {
    key = "4",
    mods = "ALT",
    action = act.ActivateTab(3),
  },
  {
    key = "5",
    mods = "ALT",
    action = act.ActivateTab(4),
  },
  {
    key = "6",
    mods = "ALT",
    action = act.ActivateTab(5),
  },
  {
    key = "7",
    mods = "ALT",
    action = act.ActivateTab(6),
  },
  {
    key = "8",
    mods = "ALT",
    action = act.ActivateTab(7),
  },
  {
    key = "9",
    mods = "ALT",
    action = act.ActivateTab(8),
  },
}

return config