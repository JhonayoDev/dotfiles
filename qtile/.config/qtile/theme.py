# ============================================================
# THEME - jhonayo
# Centraliza colores, fuentes y configuración visual
# ============================================================
SCRIPTS = "/home/jhonayo/.config/qtile/scripts"
wallpapers = {
    "primary": "~/.config/qtile/Wallpaper/the-milky-way.jpeg",
    #    "primary": "~/.config/qtile/Wallpaper/milky-way.jpeg",
    "secondary": "~/.config/qtile/Wallpaper/milky-way.jpeg",
    "mode": "fill",
}
separators = {
    "style": "rounded",  # "rounded" | "diagonal"
    "width": 18,
    "height": 30,
}
colors = {
    "bg0": "#07060D",  # Fondo secundario (barra, bordes)
    "bg1": "#161C40",  # Fondo principal barra (widgets)
    "bg2": "#007594",  # Fondo highlight (grupo activo)
    "accent": "#048DB8",  # Color Ventana activa (bordes activos)
    "fg0": "#A8E6FF",  # Texto principal
    "fg1": "#E0E0E0",  # Texto claro
    "fg2": "#006E5F",  # Texto oscuro (sobre fondos claros)
    "purple": "#4B427E",  # Acento secundario
    "dark": "#1F1D2E",  # Borde inactivo
    "alert": "#FF5555",  # Alertas (temperatura, etc.)
}

font = {
    "mono": "JetBrainsMono Nerd Font",
    "size": 15,
    "icons": "JetBrainsMono Nerd Font",
    "isize": 20,
}

terminal = "gnome-terminal"
filemanager = "nautilus"

apps = {
    "monitor": "gnome-terminal -- btop",
    "layout": "/home/jhonayo/.config/qtile/scripts/kb_toggle.sh",
}
