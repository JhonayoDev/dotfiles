local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

local M = {}

function M.setup(config)
	-- Guardar automáticamente cada 5 minutos
	resurrect.state_manager.periodic_save({
		interval_seconds = 300,
		save_workspaces = true,
		save_windows = true,
		save_tabs = true,
	})

	-- Resurrection on startup
	--wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)

	-- Actualizar plugins automáticamente
	-- wezterm.plugin.update_all() -- actualizar manualmente con :lua wezterm.plugin.update_all()
end

function M.keys()
	return {
		-- Guardar estado manualmente (workspace)
		{
			key = "S",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function(win, pane)
				resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
			end),
		},
		-- Cargar estado guardado (fuzzy finder)
		{
			key = "L",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function(win, pane)
				resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
					local type = string.match(id, "^([^/]+)")
					id = string.match(id, "([^/]+)$")
					id = string.match(id, "(.+)%..+$")
					local opts = {
						relative = true,
						restore_text = true,
						on_pane_restore = resurrect.tab_state.default_on_pane_restore,
					}
					if type == "workspace" then
						local state = resurrect.state_manager.load_state(id, "workspace")
						resurrect.workspace_state.restore_workspace(state, opts)
					elseif type == "window" then
						local state = resurrect.state_manager.load_state(id, "window")
						resurrect.window_state.restore_window(pane:window(), state, opts)
					elseif type == "tab" then
						local state = resurrect.state_manager.load_state(id, "tab")
						resurrect.tab_state.restore_tab(pane:tab(), state, opts)
					end
				end)
			end),
		},
		-- Eliminar estado guardado
		{
			key = "Q",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function(win, pane)
				resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
					resurrect.state_manager.delete_state(id)
				end, {
					title = "Eliminar Estado",
					description = "Selecciona el estado a eliminar",
					fuzzy_description = "Buscar: ",
					is_fuzzy = true,
				})
			end),
		},
	}
end

return M
