local user_profile = os.getenv("USERPROFILE")

if not user_profile then
  error("USERPROFILE is not set")
end

return dofile(user_profile .. "\\.wezterm-config\\wezterm\\wezterm.lua")