local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.setup()
	local keys = {
		-- PESTAÑAS
		{ key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
		{ key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
		{ key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
		{ key = "1", mods = "ALT", action = act.ActivateTab(0) },
		{ key = "2", mods = "ALT", action = act.ActivateTab(1) },
		{ key = "3", mods = "ALT", action = act.ActivateTab(2) },
		{ key = "4", mods = "ALT", action = act.ActivateTab(3) },
		{ key = "5", mods = "ALT", action = act.ActivateTab(4) },

		-- PANELES
		{ key = "H", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
		{ key = "D", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
		{ key = "q", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
		{ key = "Q", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = false }) },

		-- NAVEGACIÓN ENTRE PANELES
		{ key = "LeftArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") },
		{ key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") },
		{ key = "UpArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") },
		{ key = "DownArrow", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") },

		-- REDIMENSIONAR PANELES
		{ key = "LeftArrow", mods = "CTRL|SUPER", action = act.AdjustPaneSize({ "Left", 3 }) },
		{ key = "RightArrow", mods = "CTRL|SUPER", action = act.AdjustPaneSize({ "Right", 3 }) },
		{ key = "UpArrow", mods = "CTRL|SUPER", action = act.AdjustPaneSize({ "Up", 3 }) },
		{ key = "DownArrow", mods = "CTRL|SUPER", action = act.AdjustPaneSize({ "Down", 3 }) },

		{ key = "z", mods = "CTRL|SHIFT", action = act.TogglePaneZoomState },

		-- WORKSPACES
		-- Selector visual de Workspaces
		{
			key = "w",
			mods = "ALT",
			action = act.ShowLauncherArgs({ flags = "WORKSPACES" }),
		},
		-- Navegación entre workspaces
		{
			key = "n",
			mods = "ALT",
			action = act.SwitchWorkspaceRelative(1),
		},
		{
			key = "p",
			mods = "ALT",
			action = act.SwitchWorkspaceRelative(-1),
		},
		-- Crear nuevo workspace
		{
			key = "c",
			mods = "ALT",
			action = act.PromptInputLine({
				description = "Nombre del nuevo workspace:",
				action = wezterm.action_callback(function(window, pane, line)
					if line then
						window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
					end
				end),
			}),
		},
		-- Renombrar workspace actual
		{
			key = "r",
			mods = "ALT",
			action = act.PromptInputLine({
				description = "Nuevo nombre para el workspace:",
				action = wezterm.action_callback(function(window, pane, line)
					if line and line ~= "" then
						wezterm.mux.rename_workspace(window:active_workspace(), line)
					end
				end),
			}),
		},
	}

	-- RESURRECT: Agregar atajos separadamente
	local resurrect_keys = require("lua.resurrect").keys()
	for _, key in ipairs(resurrect_keys) do
		table.insert(keys, key)
	end

	return keys
end

return M
