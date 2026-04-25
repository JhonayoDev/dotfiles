local wezterm = require("wezterm")
local constants = require("constants")

local command = {
	brief = "Toggle background image",
	icon = "md_circle_opacity",
	action = wezterm.action_callback(function(window)
		local overrides = window:get_config_overrides() or {}

		if overrides.window_background_image then
			-- Si ya hay imagen → la quitamos
			overrides.window_background_image = nil
		else
			-- Si no hay imagen → la ponemos
			overrides.window_background_image = constants.bg_image
			overrides.window_background_opacity = 0.9
		end

		window:set_config_overrides(overrides)
	end),
}
return command
