local wezterm = require("wezterm")
local mux = wezterm.mux

local M = {}

function M.setup()
	wezterm.on("gui-startup", function()
		-- Workspace por defecto (siempre empieza aquí)
		local default_tab, default_pane, default_window = mux.spawn_window({
			workspace = "Home",
			cwd = os.getenv("HOME"),
		})

		-- EJEMPLOS: Puedes descomentar y personalizar cuando los necesites
		--
		-- Workspace para desarrollo Flutter
		-- mux.spawn_window({
		-- 	workspace = "dev-flutter",
		-- 	cwd = "/proyectos/flutter/app-clima",
		-- })
		--
		-- Workspace para proyectos
		mux.spawn_window({
			workspace = "Programing",
			cwd = os.getenv("HOME") .. "/dev",
		})

		-- Workspace para dotfiles
		mux.spawn_window({
			workspace = "Dotfiles",
			cwd = os.getenv("HOME") .. "/dotfiles",
		})

		-- Activa el workspace default al inicio
		mux.set_active_workspace("Dotfiles")
		mux.set_active_workspace("Programing")
		mux.set_active_workspace("Home")
	end)
end

return M
