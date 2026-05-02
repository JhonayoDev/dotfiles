local wezterm = require("wezterm")
local M = {}

function M.apply_to_config(config)
	-- Estética general de la ventana
	config.color_scheme = "Tokyo Night" -- Usamos el esquema nativo para consistencia
	config.font = wezterm.font("JetBrains Mono Nerd Font")
	config.font_size = 11.0
	-- Hacer que el menú se vea como un "Float" de Neovim
	config.command_palette_bg_color = "#16161e"
	config.command_palette_fg_color = "#c0caf5"
	config.command_palette_font_size = 12.0

	config.colors = {
		-- Colores del Selector (Fuzzy Finder)
		command_palette_rows_bg = "#16161e",
		command_palette_rows_fg = "#c0caf5",
		-- La barra de selección (como el cursor en Neovim)
		command_palette_cursor_bg = "#3b4261",
		command_palette_cursor_fg = "#ff9e64",
	}

	-- Bordes y padding para que no se vea pegado a la esquina
	config.window_padding = { left = "1cell", right = "1cell", top = "0.5cell", bottom = "0" }

	-- Configuración de la barra de pestañas (Estilo minimalista)
	config.use_fancy_tab_bar = false
	config.tab_bar_at_bottom = true
	config.hide_tab_bar_if_only_one_tab = true
end

return M
