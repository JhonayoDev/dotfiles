#!/usr/bin/env python3
"""
apply-theme.py
Lee theme.py y aplica los colores a dunstrc y genera separadores SVG.
"""

import sys
import os
import subprocess

sys.path.insert(0, os.path.expanduser("~/.config/qtile"))
from theme import colors, font, separators


# ── Funciones de separadores ──────────────────────────────────────────────────
def make_rounded_svg(w, h, left_color, right_color, direction):
    r = w // 2
    if direction == "open-right":
        return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="{w}" height="{h}" fill="{right_color}"/>
  <rect x="-{r}" width="{w}" height="{h}" rx="{r}" fill="{left_color}"/>
</svg>"""
    else:  # open-left
        return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="{w}" height="{h}" fill="{left_color}"/>
  <rect x="{r}" width="{w}" height="{h}" rx="{r}" fill="{right_color}"/>
</svg>"""


def make_diagonal_svg(w, h, left_color, right_color, direction):
    if direction == "open-right":
        # rect base = right_color, triángulo izquierdo encima = left_color
        return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="{w}" height="{h}" fill="{right_color}"/>
  <polygon points="0,0 {w},{h} 0,{h}" fill="{left_color}"/>
</svg>"""
    else:  # open-left
        return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="{w}" height="{h}" fill="{left_color}"/>
  <polygon points="0,0 {w},0 {w},{h}" fill="{right_color}"/>
</svg>"""


def make_straight_svg(w, h, left_color, right_color):
    half = w // 2
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="{half}" height="{h}" fill="{left_color}"/>
  <rect x="{half}" width="{half}" height="{h}" fill="{right_color}"/>
</svg>"""


def generate_separators(colors, separators):
    assets = os.path.expanduser("~/.config/qtile/Assets")
    os.makedirs(assets, exist_ok=True)

    w = separators["width"]
    h = separators["height"]
    style = separators["style"]

    variants = {
        "8": ("transparent", colors["fg0"], "open-left"),  # wallpaper → fg0 (launcher)
        "0": (colors["fg0"], "transparent", "open-right"),  # fg0 → bg1
        "1": (colors["bg1"], "transparent", "open-right"),  # bg1 → wallpaper (cierre)
        "2": ("transparent", colors["bg1"], "open-left"),  # wallpaper → bg1 (apertura)
        #        "8": (colors["bg0"], colors["fg0"], "open-left"),
        #        "0": (colors["fg0"], colors["bg0"], "open-right"),
        #        "1": (colors["bg1"], colors["bg0"], "open-right"),
        #        "2": (colors["bg0"], colors["bg1"], "open-left"),
    }

    for name, (bg, fg, direction) in variants.items():
        if style == "rounded":
            svg = make_rounded_svg(w, h, bg, fg, direction)
        elif style == "diagonal":
            svg = make_diagonal_svg(w, h, bg, fg, direction)
        else:
            svg = make_straight_svg(w, h, bg, fg)

        path = f"{assets}/{name}.svg"
        with open(path, "w") as f:
            f.write(svg)
        print(f"✓ {name}.svg generado ({style})")


# ── Generar dunstrc ───────────────────────────────────────────────────────────


def generate_dunstrc(colors, font):
    return f"""[global]
    monitor = 0
    follow = mouse
    width = 300
    height = 100
    origin = top-right
    offset = 10x40
    scale = 0
    notification_limit = 5
    frame_width = 2
    frame_color = "{colors["accent"]}"
    corner_radius = 10
    gap_size = 6
    font = {font["mono"]} 11
    padding = 10
    horizontal_padding = 12
    text_icon_padding = 8
    icon_position = left
    min_icon_size = 24
    max_icon_size = 32
    show_age_threshold = 60
    hide_duplicate_count = false
    sort = yes
    idle_threshold = 120
    markup = full
    format = "<b>%s</b>\\n%b"
    alignment = left
    vertical_alignment = center
    word_wrap = yes
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    icon_path = /usr/share/icons/Adwaita/16x16/status/:/usr/share/icons/Adwaita/16x16/devices/:/usr/share/icons/hicolor/16x16/apps/

[urgency_low]
    foreground = "{colors["fg0"]}"
    background = "{colors["bg1"]}"
    frame_color = "{colors["bg1"]}"
    timeout = 3

[urgency_normal]
    background = "{colors["bg0"]}"
    foreground = "{colors["fg0"]}"
    frame_color = "{colors["accent"]}"
    timeout = 5

[urgency_critical]
    background = "{colors["bg0"]}"
    foreground = "{colors["alert"]}"
    frame_color = "{colors["alert"]}"
    timeout = 5
"""


# ── Rofi ──────────────────────────────────────────────────────────────────────


def generate_rofi_themes(colors, font):
    rofi_dir = os.path.expanduser("~/.config/rofi/themes")
    os.makedirs(rofi_dir, exist_ok=True)

    colors_rasi = f"""* {{
    bg0:     {colors["bg0"]};
    bg1:     {colors["bg1"]};
    bg2:     {colors["bg2"]};
    accent:  {colors["accent"]};
    fg0:     {colors["fg0"]};
    fg1:     {colors["fg1"]};
    fg2:     {colors["fg2"]};
    font:    "{font["mono"]} 13";
}}"""

    with open(f"{rofi_dir}/colors.rasi", "w") as f:
        f.write(colors_rasi)
    print("✓ colors.rasi generado")


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    # Generar separadores
    generate_separators(colors, separators)

    # Generar dunstrc
    output = os.path.expanduser("~/.config/dunst/dunstrc")
    with open(output, "w") as f:
        f.write(generate_dunstrc(colors, font))
    print("✓ dunstrc generado")

    # Reiniciar dunst
    subprocess.run(["pkill", "dunst"], check=False)
    subprocess.Popen(["dunst"])
    print("✓ dunst reiniciado")
    # Generar colores para Rofi
    generate_rofi_themes(colors, font)
