# ============================================================
# KEYS - jhonayo
# Todos los keybinds de Qtile
# ============================================================
from libqtile.config import Key
from libqtile.lazy import lazy
from theme import terminal, filemanager

mod = "mod4"
mod1 = "mod1"

SCRIPTS = "/home/jhonayo/.config/qtile/scripts"
ROFI_THEME = "/home/jhonayo/.config/rofi/themes/control-center.rasi"


def make_keys(toggle_sticky, window_to_next_screen, window_to_prev_screen, groups):
    keys = [
        # ── Trackpad ──────────────────────────────────────────
        Key(
            [],
            "XF86LaunchB",
            lazy.spawn(f"{SCRIPTS}/trackpad_toggle.sh"),
            desc="Toggle trackpad",
        ),
        # ── Rofi ──────────────────────────────────────────────
        Key(
            [mod],
            "space",
            lazy.spawn(f"rofi -show drun -theme {ROFI_THEME}"),
            desc="Launcher",
        ),
        Key(
            [mod1],
            "space",
            lazy.spawn("/home/jhonayo/.config/rofi/scripts/control_center.sh"),
            desc="Control Center",
        ),
        # ── Navegación entre ventanas ─────────────────────────
        Key([mod], "h", lazy.layout.left(), desc="Foco izquierda"),
        Key([mod], "l", lazy.layout.right(), desc="Foco derecha"),
        Key([mod], "j", lazy.layout.down(), desc="Foco abajo"),
        Key([mod], "k", lazy.layout.up(), desc="Foco arriba"),
        # ── Mover ventanas ────────────────────────────────────
        Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Mover izquierda"),
        Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Mover derecha"),
        Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Mover abajo"),
        Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Mover arriba"),
        # ── Redimensionar ventanas ────────────────────────────
        Key(
            [mod, "control"], "Left", lazy.layout.grow_left(), desc="Agrandar izquierda"
        ),
        Key(
            [mod, "control"], "Right", lazy.layout.grow_right(), desc="Agrandar derecha"
        ),
        Key([mod, "control"], "Down", lazy.layout.grow_down(), desc="Agrandar abajo"),
        Key([mod, "control"], "Up", lazy.layout.grow_up(), desc="Agrandar arriba"),
        Key([mod], "n", lazy.layout.normalize(), desc="Normalizar tamaños"),
        Key(
            [mod, "shift"],
            "Right",
            lazy.layout.increase_ratio(),
            desc="Agrandar master",
        ),
        Key(
            [mod, "shift"], "Left", lazy.layout.decrease_ratio(), desc="Achicar master"
        ),
        # ── Ventanas ──────────────────────────────────────────
        Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Pantalla completa"),
        Key([mod], "v", lazy.window.toggle_floating(), desc="Toggle flotante"),
        Key([mod], "q", lazy.window.kill(), desc="Cerrar ventana"),
        Key([mod], "s", toggle_sticky, desc="Toggle sticky"),
        # ── Sistema ───────────────────────────────────────────
        Key([mod], "Return", lazy.spawn(terminal), desc="Terminal"),
        Key([mod], "Tab", lazy.next_layout(), desc="Cambiar layout"),
        Key([mod, "control"], "r", lazy.reload_config(), desc="Recargar config"),
        Key([mod, "control"], "q", lazy.shutdown(), desc="Salir de Qtile"),
        Key([mod], "e", lazy.spawn(filemanager), desc="Gestor de archivos"),
        Key(
            [mod],
            "m",
            lazy.spawn(f"{SCRIPTS}/kb_toggle.sh"),
            desc="Cambiar layout teclado",
        ),
        # ── Monitores ─────────────────────────────────────────
        Key([mod], "period", lazy.next_screen(), desc="Foco siguiente monitor"),
        Key([mod], "comma", lazy.prev_screen(), desc="Foco monitor anterior"),
        Key(
            [mod, "shift"],
            "period",
            window_to_next_screen,
            desc="Ventana al siguiente monitor",
        ),
        Key(
            [mod, "shift"],
            "comma",
            window_to_prev_screen,
            desc="Ventana al monitor anterior",
        ),
        # ── Media ─────────────────────────────────────────────
        Key(
            [],
            "XF86AudioRaiseVolume",
            lazy.spawn(
                'bash -c \'sink=$(pactl get-default-sink) && pactl set-sink-volume $sink +5% && notify-send --replace-id=1000 --expire-time=1200 "󰕾 Volumen" "$(pactl get-sink-volume $sink | grep -oP "\\d+(?=%)" | head -1)%"\''
            ),
            desc="Volumen +",
        ),
        Key(
            [],
            "XF86AudioLowerVolume",
            lazy.spawn(
                'bash -c \'sink=$(pactl get-default-sink) && pactl set-sink-volume $sink -5% && notify-send --replace-id=1000 --expire-time=1200 "󰖀 Volumen" "$(pactl get-sink-volume $sink | grep -oP "\\d+(?=%)" | head -1)%"\''
            ),
            desc="Volumen -",
        ),
        Key(
            [],
            "XF86AudioMute",
            lazy.spawn(
                'bash -c \'pactl set-sink-mute @DEFAULT_SINK@ toggle && notify-send --replace-id=1000 --expire-time=1200 "󰝟 Volumen" "Mute toggle"\''
            ),
            lazy.widget["volume"].eval("self.force_update()"),
            desc="Mute",
        ),
        Key([], "XF86AudioPlay", lazy.spawn("playerctl play-pause"), desc="Play/Pause"),
        Key([], "XF86AudioPrev", lazy.spawn("playerctl previous"), desc="Anterior"),
        Key([], "XF86AudioNext", lazy.spawn("playerctl next"), desc="Siguiente"),
        # ── Brillo ────────────────────────────────────────────
        Key(
            [],
            "F1",
            lazy.spawn(
                'bash -c \'brightnessctl s 10%- && notify-send --replace-id=3000 --expire-time=1200 "Brillo" "$(brightnessctl g | awk "{print int(\\$1/$(brightnessctl m)*100)}")%"\''
            ),
            desc="Brillo -",
        ),
        Key(
            [],
            "F2",
            lazy.spawn(
                'bash -c \'brightnessctl s 10%+ && notify-send --replace-id=3000 --expire-time=1200 "Brillo" "$(brightnessctl g | awk "{print int(\\$1/$(brightnessctl m)*100)}")%"\''
            ),
            desc="Brillo +",
        ),
        # ── Screenshots ───────────────────────────────────────
        Key([mod], "p", lazy.spawn("flameshot gui"), desc="Screenshot región"),
        Key(
            [mod, "shift"],
            "p",
            lazy.spawn("flameshot full -c -p /home/jhonayo/Pictures/"),
            desc="Screenshot completo",
        ),
    ]

    # Keybinds para grupos
    for i in groups:
        keys.extend(
            [
                Key(
                    [mod],
                    i.name,
                    lazy.group[i.name].toscreen(),
                    desc=f"Ir al grupo {i.name}",
                ),
                Key(
                    [mod, "shift"],
                    i.name,
                    lazy.window.togroup(i.name, switch_group=False),
                    desc=f"Mover ventana al grupo {i.name}",
                ),
            ]
        )

    return keys
