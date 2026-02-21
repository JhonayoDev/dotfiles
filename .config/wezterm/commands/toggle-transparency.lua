local wezterm = require("wezterm")

local command = {
	brief = "Toggle terminal transparency",
	icon = "md_circle_opacity",
	action = wezterm.action_callback(function(window)
		local overrides = window:get_config_overrides() or {}
		local effective = window:effective_config()

		local current_opacity = overrides.window_background_opacity or effective.window_background_opacity

		if current_opacity == 1 then
			overrides.window_background_opacity = 0.9
		else
			overrides.window_background_opacity = 1
		end

		window:set_config_overrides(overrides)
	end),
}

return command
