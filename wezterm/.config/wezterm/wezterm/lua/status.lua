local wezterm = require("wezterm")

local M = {}

function M.setup()
	wezterm.on("update-right-status", function(window, pane)
		local workspace = window:active_workspace()
		local time = wezterm.strftime("%H:%M:%S")

		-- Mostrar en la esquina derecha de la barra de pestañas
		window:set_right_status(wezterm.format({
			{ Foreground = { Color = "#0FC5ED" } },
			{ Text = " [" .. workspace .. "] " },
			{ Foreground = { Color = "#FFE073" } },
			{ Text = time .. " " },
		}))
	end)
end

return M
