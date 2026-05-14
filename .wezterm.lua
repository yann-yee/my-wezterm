local user_profile = os.getenv("USERPROFILE")
local home_dir = user_profile or os.getenv("HOME")

if not home_dir then
  error("USERPROFILE or HOME is not set")
end

if user_profile then
  return dofile(user_profile .. "\\.wezterm-config\\wezterm\\wezterm.lua")
end

return dofile(home_dir .. "/.wezterm-config/wezterm/wezterm.lua")