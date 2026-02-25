local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Importar módulos
local constants = require("constants")
local commands = require("commands")
local keys = require("lua.keys")
local workspaces = require("lua.workspaces")
local status = require("lua.status")
local resurrect = require("lua.resurrect")
--local appearance = require("lua.appearance")

-- Aplicar configuraciones de módulos
config.keys = keys.setup()
status.setup()
workspaces.setup()
--appearance.apply_to_config(config)

-- CONFIGURACIÓN DEL MULTIPLEXOR (Servidor)
config.unix_domains = {
	{ name = "unix" },
}
config.default_gui_startup_args = { "connect", "unix" }

-- FUENTE
--config.font = wezterm.font("MesloLGS NF", { weight = "Regular" })
--config.font_size = 12
config.font = wezterm.font_with_fallback({
	{ family = "MesloLGS NF", weight = "Regular" },
})

config.font_size = 12.0 -- ajusta si cambió visualmente
-- FONDO
-- config.window_background_image = constants.bg_image

-- PESTAÑAS
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.window_background_opacity = 0.9
-- VENTANA
config.window_decorations = "TITLE | RESIZE"

-- Paleta de comandos
wezterm.on("augment-command-palette", function()
	return commands
end)

-- PADDING
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}

-- SCROLLBACK
config.scrollback_lines = 5000

-- COLOR SCHEME
config.colors = {
	foreground = "#CBE0F0",
	background = "#011423",
	cursor_bg = "white",
	cursor_border = "white",
	cursor_fg = "#011423",
	selection_bg = "#033259",
	selection_fg = "#CBE0F0",
	ansi = {
		"#214969",
		"#E52E2E",
		"#44FFB1",
		"#FFE073",
		"#0FC5ED",
		"#a277ff",
		"#24EAF7",
		"#24EAF7",
	},
	brights = {
		"#214969",
		"#E52E2E",
		"#44FFB1",
		"#FFE073",
		"#A277FF",
		"#a277ff",
		"#24EAF7",
		"#24EAF7",
	},
}

-- RENDIMIENTO
config.front_end = "OpenGL"

-- RESURRECT_WEZTERM
resurrect.setup(config)

return config
