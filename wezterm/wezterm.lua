local wezterm = require("wezterm")

local config = wezterm.config_builder and wezterm.config_builder() or {}

local palette = {
	background = "#09111d",
	background_alt = "#121e31",
	chrome = "#132136",
	chrome_inactive = "#0d1727",
	path_band = "#315f84",
	path_glow = "#62567f",
	accent = "#f4c084",
	accent_soft = "#8e5a72",
	text = "#e8edf6",
	muted = "#97a8c2",
	selection = "#26456a",
	error = "#ff8f7a",
	success = "#81d4b3",
}

local tab_palette = {
	{ active = "#315f84", hover = "#3f759f", inactive = "#1f3248" },
	{ active = "#6d557f", hover = "#83679a", inactive = "#33263e" },
	{ active = "#7d5f4b", hover = "#9a755c", inactive = "#3d2c24" },
	{ active = "#3f6f67", hover = "#50887e", inactive = "#203831" },
	{ active = "#7b4f67", hover = "#955f7d", inactive = "#3a2432" },
}

local user_profile = os.getenv("USERPROFILE")
local tools_root = os.getenv("WEZTERM_TOOLS_ROOT") or "C:\\Users\\qwer\\Desktop\\WezTerm\\Tools"
local config_root = user_profile and (user_profile .. "\\.wezterm-config\\wezterm") or nil
local git_bash = "C:\\Program Files\\Git\\bin\\bash.exe"
local bash_rc = config_root and (config_root .. "\\shell\\bashrc") or nil
local starship_config = config_root and (config_root .. "\\starship.toml") or nil
local font_root = tools_root .. "\\JetBrainsMono"

local function file_exists(path)
	local handle = io.open(path, "r")
	if handle then
		handle:close()
		return true
	end

	return false
end

local function path_join(...)
	return table.concat({ ... }, ";")
end

local function tab_title(tab)
	local title = tab.tab_title
	if not title or #title == 0 then
		title = tab.active_pane.title
	end

	return title
end

local function tab_colors(tab)
	return tab_palette[(tab.tab_index % #tab_palette) + 1]
end

wezterm.on("format-tab-title", function(tab, _, _, _, hover, max_width)
	local title = wezterm.truncate_right(tab_title(tab), math.max(max_width - 8, 6))
	local colors = tab_colors(tab)
	local bg = colors.inactive
	local fg = palette.muted

	if tab.is_active then
		bg = colors.active
		fg = palette.text
	elseif hover then
		bg = colors.hover
		fg = palette.text
	end

	return {
		{ Background = { Color = palette.chrome } },
		{ Foreground = { Color = bg }, Text = "" },
		{ Background = { Color = bg }, Foreground = { Color = fg }, Text = string.format(" %d %s ", tab.tab_index + 1, title) },
		{ Foreground = { Color = bg }, Text = "" },
		{ Background = { Color = palette.chrome }, Text = " " },
	}
end)

local tool_paths = {
	tools_root,
	tools_root .. "\\nvim\\bin",
	tools_root .. "\\ripgrep",
	tools_root .. "\\fd",
	tools_root .. "\\lazygit",
	tools_root .. "\\yazi",
	tools_root .. "\\bat",
	tools_root .. "\\eza",
	tools_root .. "\\starship",
}

config.default_cwd = user_profile
config.automatically_reload_config = true
config.check_for_updates = false
config.colors = {
	foreground = palette.text,
	background = palette.background,
	cursor_bg = palette.accent,
	cursor_fg = palette.background,
	cursor_border = palette.accent,
	selection_bg = palette.selection,
	selection_fg = palette.text,
	scrollbar_thumb = palette.accent_soft,
	split = palette.path_glow,
	tab_bar = {
		background = palette.chrome,
		active_tab = {
			bg_color = tab_palette[1].active,
			fg_color = palette.text,
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = tab_palette[1].inactive,
			fg_color = palette.muted,
		},
		inactive_tab_hover = {
			bg_color = tab_palette[1].hover,
			fg_color = palette.text,
		},
		new_tab = {
			bg_color = palette.chrome,
			fg_color = palette.muted,
		},
		new_tab_hover = {
			bg_color = tab_palette[1].hover,
			fg_color = palette.text,
		},
		inactive_tab_edge = palette.chrome,
	},
}
if file_exists(font_root .. "\\JetBrainsMonoNerdFontMono-Regular.ttf") then
	config.font_dirs = { font_root }
end
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font Mono",
	"JetBrainsMono Nerd Font",
	"Consolas",
})
config.font_size = 12.0
config.window_background_opacity = 0.88
config.text_background_opacity = 0.92
config.win32_system_backdrop = "Acrylic"
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.integrated_title_button_alignment = "Right"
config.integrated_title_button_color = "Auto"
config.integrated_title_button_style = "Gnome"
config.window_frame = {
	font = wezterm.font_with_fallback({
		"JetBrainsMono Nerd Font",
		"JetBrainsMono Nerd Font Mono",
	}),
	font_size = 11.0,
	active_titlebar_bg = palette.chrome,
	inactive_titlebar_bg = palette.chrome_inactive,
	active_titlebar_fg = palette.text,
	inactive_titlebar_fg = palette.muted,
}
config.skip_close_confirmation_for_processes_named = {
	"bash.exe",
	"bash",
	"sh",
	"zsh",
	"fish",
	"tmux",
	"nu",
	"cmd.exe",
	"pwsh.exe",
	"powershell.exe",
}
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = true
config.use_fancy_tab_bar = true
config.tab_max_width = 30
config.window_padding = {
	left = 14,
	right = 14,
	top = 10,
	bottom = 12,
}
config.set_environment_variables = {
	WEZTERM_TOOLS_ROOT = tools_root,
	STARSHIP_CONFIG = starship_config,
	PATH = path_join(table.concat(tool_paths, ";"), os.getenv("PATH") or ""),
}

if bash_rc and file_exists(git_bash) and file_exists(bash_rc) then
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
			label = "LazyGit",
			args = {
				git_bash,
				"--noprofile",
				"--rcfile",
				bash_rc,
				"-ic",
				"exec lazygit",
			},
		},
		{
			label = "Yazi",
			args = {
				git_bash,
				"--noprofile",
				"--rcfile",
				bash_rc,
				"-ic",
				"exec yazi",
			},
		},
	}
end

return config
