# ============================================================
# QTILE CONFIG - jhonayo
# ============================================================
# ESTRUCTURA GENERAL:
#   1. Imports y variables globales
#   2. Sticky windows (ventanas que siguen entre grupos)
#   3. Detección de monitores
#   4. Grupos (workspaces) - 8 en total, 4 por monitor
#   5. Keybinds
#   6. Layouts
#   7. Widgets y barras
#   8. Screens (pantallas)
#   9. Configuración general y hooks
# ============================================================

# ── 1. IMPORTS Y VARIABLES GLOBALES ─────────────────────────

import os
import subprocess
from libqtile import bar, layout, widget, hook, qtile
from libqtile.config import Click, Drag, Group, Key, Match, Screen, KeyChord
from libqtile.lazy import lazy
from theme import colors, font, terminal as TERMINAL, filemanager as FILEMANAGER

mod         = "mod4"       # Tecla Super (Windows)
mod1        = "mod1"       # Tecla Alt
terminal    = TERMINAL
filemanager = FILEMANAGER


# ── 2. STICKY WINDOWS ───────────────────────────────────────
# Una ventana "sticky" sigue al usuario cuando cambia de grupo.
# Útil para tener música o un chat siempre visible.
# Activar/desactivar con: Super + S
# Firefox Picture-in-Picture se vuelve sticky automáticamente.

sticky_windows = []

@lazy.function
def toggle_sticky_windows(qtile, window=None):
    if window is None:
        window = qtile.current_screen.group.current_window
    if window in sticky_windows:
        sticky_windows.remove(window)
    else:
        sticky_windows.append(window)
    return window

@hook.subscribe.setgroup
def move_sticky_windows():
    for window in sticky_windows:
        window.togroup()

@hook.subscribe.client_killed
def remove_sticky_windows(window):
    if window in sticky_windows:
        sticky_windows.remove(window)

@hook.subscribe.client_managed
def auto_sticky_windows(window):
    # Firefox PiP se vuelve sticky automáticamente
    info = window.info()
    if (info['wm_class'] == ['Toolkit', 'firefox']
            and info['name'] == 'Picture-in-Picture'):
        sticky_windows.append(window)

@lazy.function
def window_to_next_screen(qtile):
    current = qtile.current_screen.index
    total = len(qtile.screens)
    next_screen = (current + 1) % total
    qtile.current_window.toscreen(next_screen)

@lazy.function
def window_to_prev_screen(qtile):
    current = qtile.current_screen.index
    total = len(qtile.screens)
    prev_screen = (current - 1) % total
    qtile.current_window.toscreen(prev_screen)


# ── 3. DETECCIÓN DE MONITORES ────────────────────────────────
# Se ejecuta al arrancar Qtile para saber cuántos monitores
# físicos están activos. Esto determina cómo se reparten
# los grupos y qué barras se crean.
#
# Un monitor activo = aparece en xrandr con resolución asignada
# (ej: "HDMI-1 connected 1920x1080+0+0")

def get_num_monitors():
    result = subprocess.run(['xrandr', '--query'], capture_output=True, text=True)
    count = 0
    for line in result.stdout.splitlines():
        if ' connected' in line and 'disconnected' not in line:
            # Excluir monitores sin resolución asignada (apagados)
            # Una pantalla activa tiene formato: "NAME connected WxH+X+Y"
            # Una apagada tiene: "NAME connected (normal...)"
            if '(' not in line.split('connected')[1].strip()[:5]:
                count += 1
    return count


# Se calcula UNA sola vez al cargar el config.
# Si cambiás monitores necesitás reiniciar Qtile.
NUM_MONITORS = get_num_monitors()


# ── 4. GRUPOS (WORKSPACES) ───────────────────────────────────
# Siempre se crean 8 grupos, pero se distribuyen así:
#
#   1 monitor:   grupos 1-4 visibles en la barra
#   2 monitores: monitor principal → grupos 1-4
#                monitor secundario → grupos 5-8
#
# Esto imita el comportamiento de dwm donde cada monitor
# tiene su propio conjunto de tags independiente.
#
# FLUJO TÍPICO:
#   Monitor principal:  1=código/nvim, 2=notas, 3=extra, 4=extra
#   Monitor secundario: 5=docs/browser, 6=música, 7=extra, 8=extra
#
# Para mandar una ventana al otro monitor:
#   Super + Shift + 5  → manda la ventana al grupo 5 (secundario)
#   Super + Shift + 1  → manda la ventana al grupo 1 (principal)

#groups = [Group(str(i), label="⬤") for i in range(1, 9)]
groups = [
    # Monitor principal
    Group("1", label="P1"),
    Group("2", label="P2"),
    Group("3", label="P3"),
    Group("4", label="P4"),
    # Monitor secundario
    Group("5", label="S1"),
    Group("6", label="S2"),
    Group("7", label="S3"),
    Group("8", label="S4"),
]
GROUPS_PRIMARY   = ["1", "2", "3", "4"]
GROUPS_SECONDARY = ["5", "6", "7", "8"]


# ── 5. KEYBINDS ─────────────────────────────────────────────



keys = [
    # ── Trackpad  ──────────────────
    Key([], "XF86LaunchB", lazy.spawn('/home/jhonayo/.config/qtile/scripts/trackpad_toggle.sh'), desc="Toggle trackpad"),


    # ── Rofi  ──────────────────
#    Key([mod], "space", lazy.spawn('/home/jhonayo/.config/rofi/scripts/control_center.sh'), desc="Control Center"),
    Key([mod], "space",  lazy.spawn("rofi -show drun -theme /home/jhonayo/.config/rofi/themes/control-center.rasi"), desc="Launcher"),
    Key([mod1], "space", lazy.spawn('/home/jhonayo/.config/rofi/scripts/control_center.sh'), desc="Control Center"),


    # ── Navegación entre ventanas ──────────────────────────
    Key([mod], "h",     lazy.layout.left(),  desc="Foco izquierda"),
    Key([mod], "l",     lazy.layout.right(), desc="Foco derecha"),
    Key([mod], "j",     lazy.layout.down(),  desc="Foco abajo"),
    Key([mod], "k",     lazy.layout.up(),    desc="Foco arriba"),
#    Key([mod], "space", lazy.layout.next(),  desc="Siguiente ventana"),

    # ── Mover ventanas dentro del layout ──────────────────
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(),  desc="Mover izquierda"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Mover derecha"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(),  desc="Mover abajo"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(),    desc="Mover arriba"),

    # ── Redimensionar ventanas ─────────────────────────────
    Key([mod, "control"], "Left", lazy.layout.grow_left(),  desc="Agrandar izquierda"),
    Key([mod, "control"], "Right", lazy.layout.grow_right(), desc="Agrandar derecha"),
    Key([mod, "control"], "Down", lazy.layout.grow_down(),  desc="Agrandar abajo"),
    Key([mod, "control"], "Up", lazy.layout.grow_up(),    desc="Agrandar arriba"),
    Key([mod], "n", lazy.layout.normalize(), desc="Normalizar tamaños"),

# Funcional para ajustar ancho en Title
    Key([mod, "shift"], "Right", lazy.layout.increase_ratio(), desc="Agrandar master"),
    Key([mod, "shift"], "Left", lazy.layout.decrease_ratio(), desc="Achicar master"),

    # ── Ventanas ───────────────────────────────────────────
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Pantalla completa"),
    Key([mod], "v", lazy.window.toggle_floating(),   desc="Toggle flotante"),
    Key([mod], "q", lazy.window.kill(),              desc="Cerrar ventana"),
#    Key([mod, "shift"], "Return", lazy.layout.toggle_split(), desc="Toggle split"),
    Key([mod], "s", toggle_sticky_windows(), desc="Toggle sticky"),

# Desactivado por no usar ese modo de ventanas
#    Key([mod, "shift"], "Return", lazy.layout.swap_main(), desc="Promover ventana al master"),

    # ── Sistema ────────────────────────────────────────────
    Key([mod], "Return",       lazy.spawn(terminal),   desc="Terminal"),
    Key([mod], "Tab",          lazy.next_layout(),     desc="Cambiar layout"),
    Key([mod, "control"], "r", lazy.reload_config(),   desc="Recargar config"),
    Key([mod, "control"], "q", lazy.shutdown(),        desc="Salir de Qtile"),
#    Key([mod1], "Space",       lazy.spawn("rofi -theme rounded-green-dark -show drun"), desc="Launcher"),
    Key([mod], "e",            lazy.spawn(filemanager), desc="Gestor de archivos"),
    Key([mod], "m", lazy.spawn('/home/jhonayo/.config/qtile/scripts/kb_toggle.sh'), desc="Cambiar layout teclado"),

    # ── Monitores ──────────────────────────────────────────
    # Super + .      → mover FOCO al siguiente monitor
    # Super + ,      → mover FOCO al monitor anterior
    # Super+Shift+.  → mover VENTANA al siguiente monitor
    # Super+Shift+,  → mover VENTANA al monitor anterior
    Key([mod], "period",          lazy.next_screen(),              desc="Foco siguiente monitor"),
    Key([mod], "comma",           lazy.prev_screen(),              desc="Foco monitor anterior"),
#   Key([mod, "shift"], "period", lazy.window.to_next_screen(),    desc="Ventana al siguiente monitor"),
#    Key([mod, "shift"], "comma",  lazy.window.to_prev_screen(),    desc="Ventana al monitor anterior"),

    Key([mod, "shift"], "period", window_to_next_screen, desc="Ventana al siguiente monitor"),
    Key([mod, "shift"], "comma",  window_to_prev_screen, desc="Ventana al monitor anterior"),


    # ── Media ──────────────────────────────────────────────
    Key([], "XF86AudioRaiseVolume",  lazy.spawn("pactl set-sink-volume 0 +1%"),              desc="Volumen +"),
    Key([], "XF86AudioLowerVolume",  lazy.spawn("pactl set-sink-volume 0 -1%"),              desc="Volumen -"),
    Key([], "XF86AudioMute",         lazy.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle"), desc="Mute"),
    Key([], "XF86AudioPlay",         lazy.spawn("playerctl play-pause"),                     desc="Play/Pause"),
    Key([], "XF86AudioPrev",         lazy.spawn("playerctl previous"),                       desc="Anterior"),
    Key([], "XF86AudioNext",         lazy.spawn("playerctl next"),                           desc="Siguiente"),
    Key([], "XF86MonBrightnessUp",   lazy.spawn("brightnessctl s 5%+"),                      desc="Brillo +"),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl s 5%-"),                      desc="Brillo -"),

    # ── Screenshots ────────────────────────────────────────
#    Key([],          "Print", lazy.spawn("flameshot gui"),                    desc="Screenshot región"),
#    Key(["control"], "Print", lazy.spawn("flameshot full -c -p ~/Pictures/"), desc="Screenshot completo"),

    Key([mod], "p", lazy.spawn("flameshot gui"), desc="Screenshot región"),
    Key([mod, "shift"], "p", lazy.spawn("flameshot full -c -p /home/jhonayo/Pictures/"), desc="Screenshot completo"),

]

# Keybinds para cada grupo
# Super + 1-8        → ir al grupo N
# Super + Shift + 1-8 → mover ventana al grupo N (y seguirla)
for i in groups:
    keys.extend([
        Key([mod], i.name,
            lazy.group[i.name].toscreen(),
            desc=f"Ir al grupo {i.name}"),
        Key([mod, "shift"], i.name,
            lazy.window.togroup(i.name, switch_group=False),
            desc=f"Mover ventana al grupo {i.name}"),
    ])


# ── 6. LAYOUTS ───────────────────────────────────────────────
# Cambiar layout: Super + Tab
#
# Columns  → tiling por columnas (default, el más flexible)
# Max      → una ventana ocupa todo (con barra visible)
# Floating → ventanas flotantes libres
# Matrix   → grilla uniforme
# MonadWide→ master horizontal + stack (útil en monitores anchos)
# Tile     → master izquierda + stack derecha (clásico dwm-style)

layouts = [
#    layout.MonadTall(margin=6, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3, ratio=0.6,),
    layout.Tile(margin=6, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3,ratio =0.6, ),
    layout.Columns(margin=6, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3),
    layout.Max(margin=6, border_focus=colors['accent'], border_normal=colors['dark'], border_width=0),
#    layout.Floating(margin=0, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3),
#    layout.Matrix(margin=0, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3),
#    layout.MonadWide(margin=0, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3),
#    layout.Tile(margin=0, border_focus=colors['accent'], border_normal=colors['dark'], border_width=3),
]



# ── 7. BARRAS ────────────────────────────────────────────────
# bar_primary:   barra completa (CPU, RAM, volumen, systray, fecha, hora)
# bar_secondary: barra simplificada (grupos, ventana activa, fecha, hora)
#
# IMPORTANTE: widget.Systray solo puede existir UNA vez en todo Qtile.
# Por eso solo está en la barra principal.

widget_defaults = dict(font=font['mono'], fontsize=font['size'], padding=4,)
extension_defaults = widget_defaults.copy()
def open_launcher():
    qtile.spawn("rofi -theme rounded-green-dark -show drun")

def open_btop():
    qtile.spawn("alacritty --hold -e btop")

def make_bar_primary():
    return bar.Bar(
            [
                widget.Spacer(
                    length=18, 
                    background=colors['bg0'],
                    ),
                widget.Image(
                    filename='~/.config/qtile/Assets/launch_Icon.png',
                    background=colors['bg0'], 
                    mouse_callbacks = {'Button1': open_launcher},
                    ),
                widget.Image(
                    filename='~/.config/qtile/Assets/6.png',
                    ),

        # Muestra solo los grupos del monitor principal (1-4)
        widget.GroupBox(
            fontsize=font['size'], borderwidth=0, highlight_method='block',
            active=colors['fg0'], block_highlight_text_color="#00F076",
            highlight_color=colors['purple'], inactive=colors['fg2'],
            foreground=colors['bg1'], background=colors['bg1'],
            this_current_screen_border=colors['bg2'], this_screen_border=colors['purple'],
            other_current_screen_border=colors['purple'], other_screen_border=colors['purple'],
            urgent_border=colors['purple'], rounded=True, disable_drag=True,
            visible_groups=GROUPS_PRIMARY,
        ),

        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/2.png'),
        widget.CurrentLayout(background=colors['bg1'], font=font['mono'], fontsize=font['size'], padding=0),
        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/2.png'),
        widget.WindowName(background=colors['bg1'], format="{name}", font=font['mono'],
                          fontsize=font['size'], empty_group_string='Desktop', padding=0),
        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/1.png', background=colors['purple']),

	    # Widget de Idioma Input
        widget.TextBox(
                text="󰌌",
                font=font['icons'],
                fontsize=font['isize'],
                background=colors['bg1'],
                foreground=colors['fg0'],
                padding=4,
                mouse_callbacks={'Button1': lambda: qtile.spawn("alacritty --hold -e btop")},
        ),
	    widget.GenPollText(
	            func=lambda: open('/tmp/kb_layout').read().strip()
	                         if os.path.exists('/tmp/kb_layout') else 'US',
	            update_interval=2,
	            font=font['mono'],
	            fontsize=font['size'],
	            background=colors['bg1'],
	            padding=4,
	    ),
	    widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/1.png', background=colors['purple']),


        #Widget de CPU
        widget.TextBox(
            text="󰍹",
            font=font['icons'],
            fontsize=font['isize'],
            background=colors['bg1'],
            foreground=colors['fg0'],
            padding=6,
            mouse_callbacks={'Button1': open_btop},
        ),
        widget.Spacer(length=4, background=colors['bg1']),
        widget.CPU(
            font = font['mono'],
            format='CPU {load_percent:4.1f}%',
            fontsize=font['size'],
            margin = 0,
            padding = 0,
            background = colors['bg1'],
            mouse_callbacks = {'Button1': open_btop},
        ),
        widget.Spacer(length=6, background=colors['bg1']),
        #Widget de RAM
        widget.TextBox(
            text="󰍛",
            font=font['icons'],
            fontsize=font['isize'],
            background=colors['bg1'],
            foreground=colors['fg0'],
            padding=6,
            mouse_callbacks={'Button1': lambda: qtile.spawn("alacritty --hold -e btop")},
        ),
        widget.Spacer(length=4, background=colors['bg1']),
        widget.Memory(
                format='{MemUsed:4.1f}/{MemTotal:4.1f} GB´',
                measure_mem='G',
                font=font['mono'],
                fontsize=font['size'],
                padding=0,
                background=colors['bg1'],
                mouse_callbacks={'Button2': lambda: qtile.spawn("alacritty --hold -e btop")},
        ),
        widget.Spacer(length=6, background=colors['bg1']),
        #Widget de temperatura
        widget.TextBox(
            text="󰔏",
            font=font['icons'],
            fontsize=font['isize'],
            background=colors['bg1'],
            foreground=colors['fg0'],
            padding=6,
        ),
        widget.Spacer(length=4, background=colors['bg1']),
        widget.ThermalSensor(
            font=font['mono'],
            fontsize=font['size'],
            padding=0,
            background=colors['bg1'],
            foreground=colors['fg0'],
            foreground_alert=colors['alert'],  # rojo cuando está caliente
            threshold=80,                 # alerta a partir de 80°C
            tag_sensor="Package id 0",   # sensor principal del Mac
        ),
        widget.Spacer(length=6, background=colors['bg1']),

        # Systray: íconos del sistema. Solo puede haber uno en toda la config.
        widget.Systray(background=colors['bg1'], icon_size=24, padding=4),
 
	    # Seccion del volumen 
      	widget.Spacer(length=6, background=colors['bg1']),

        #Falta el icono de volumen

        widget.Spacer(length=6, background=colors['bg1']),
        widget.PulseVolume(font=font['mono'], fontsize=font['size'], padding=0, background=colors['bg1']),

        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/2.png', background=colors['purple']),
        widget.Spacer(length=0, background=colors['bg1']),

        widget.Image(filename='~/.config/qtile/Assets/Bar-Icons/calendar.svg',
                     background=colors['bg1'], margin_y=3, scale=True),
        widget.Spacer(length=6, background=colors['bg1']),
        widget.Clock(format='%d/%m/%y ', background=colors['bg1'], font=font['mono'], fontsize=font['size'], padding=0),
        widget.Image(filename='~/.config/qtile/Assets/Bar-Icons/clock.svg',
                     background=colors['bg1'], margin_y=3, margin_x=5, scale=True),
        widget.Clock(format='%H:%M', background=colors['bg1'], font=font['mono'], fontsize=font['size'], padding=0),
        widget.Spacer(length=18, background=colors['bg1']),
    ], 30, margin=[0, 8, 6, 8])


def make_bar_secondary():
    return bar.Bar([
        widget.Spacer(length=18, background=colors['bg0']),

        # Muestra solo los grupos del monitor secundario (5-8)
        widget.GroupBox(
            fontsize=font['size'], borderwidth=0, highlight_method='block',
            active=colors['fg0'], block_highlight_text_color="#00F076",
            highlight_color=colors['purple'], inactive=colors['fg2'],
            foreground=colors['bg1'], background=colors['bg1'],
            this_current_screen_border=colors['bg2'], this_screen_border=colors['purple'],
            other_current_screen_border=colors['purple'], other_screen_border=colors['purple'],
            rounded=True, disable_drag=True,
            visible_groups=GROUPS_SECONDARY,
        ),

        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/2.png'),
        widget.CurrentLayout(background=colors['bg1'], font=font['mono'], fontsize=font['size'], padding=0),
        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/2.png'),
#        widget.WindowName(background=colors['bg1'], font=font['mono'],
#                          fontsize=font['size'], empty_group_string='Desktop', padding=0),
        widget.Spacer(background=colors['bg1']),
        widget.Image(filename='~/.config/qtile/Assets/1.png', background=colors['purple']),

        widget.CPU(font=font['mono'], format='CPU:({load_percent:.1f}%)',
                   fontsize=font['size'], padding=0, background=colors['bg1'],
                   mouse_callbacks={'Button1': open_btop}),

        widget.Image(filename='~/.config/qtile/Assets/5.png'),
        widget.Image(filename='~/.config/qtile/Assets/1.png', background=colors['purple']),

        widget.Image(filename='~/.config/qtile/Assets/Bar-Icons/calendar.svg',
                     background=colors['bg1'], margin_y=3, scale=True),
        widget.Spacer(length=6, background=colors['bg1']),
        widget.Clock(format='%d/%m/%y ', background=colors['bg1'], font=font['mono'], fontsize=font['size'], padding=0),
        widget.Image(filename='~/.config/qtile/Assets/Bar-Icons/clock.svg',
                     background=colors['bg1'], margin_y=3, margin_x=5, scale=True),
        widget.Clock(format='%H:%M', background=colors['bg1'], font=font['mono'], fontsize=font['size'], padding=0),
        widget.Spacer(length=18, background=colors['bg1']),
    ], 30, margin=[0, 8, 6, 8])


# ── 8. SCREENS ───────────────────────────────────────────────
# Se crea un Screen por cada monitor activo.
# El primero siempre tiene la barra completa.
# Los adicionales tienen la barra secundaria.

screens = [
    Screen(
        top=make_bar_primary(),
        wallpaper='~/.config/qtile/Wallpaper/catilloinfinito.jpg',
        wallpaper_mode='fill',
    )
] + [
    Screen(
        top=make_bar_secondary(),
        wallpaper='~/.config/qtile/Wallpaper/Skyscraper.png',
        wallpaper_mode='fill',
    )
    for _ in range(NUM_MONITORS - 1)
]


# ── 9. CONFIGURACIÓN GENERAL ─────────────────────────────────

floating_layout = layout.Floating(
    border_focus=colors['accent'],
    border_normal=colors['dark'],
    border_width=3,
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),
        Match(wm_class="makebranch"),
        Match(wm_class="maketag"),
        Match(wm_class="ssh-askpass"),
        Match(title="branchdialog"),
        Match(title="pinentry"),
    ]
)

mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),     start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules  = []
follow_mouse_focus = True    # el foco sigue al mouse
bring_front_click  = False
cursor_warp        = False   # el cursor NO salta al cambiar de grupo
auto_fullscreen    = True
focus_on_window_activation = "smart"
reconfigure_screens = True   # re-evalúa screens si cambian monitores
auto_minimize      = True
wl_input_rules     = None


# ── HOOKS ────────────────────────────────────────────────────

@hook.subscribe.startup_once
def autostart():
    # Se ejecuta UNA sola vez al iniciar (no en reloads con Super+Ctrl+R).
    # El script configura xrandr y lanza picom, nm-applet, etc.
    home = os.path.expanduser('~/.config/qtile/scripts/autostart.sh')
    subprocess.call([home])

@hook.subscribe.startup_complete
def assign_groups_to_screens():
    # Asigna el grupo inicial a cada monitor al arrancar.
    # Sin esto, ambos monitores arrancan mostrando el mismo grupo.
    #
    # Con 2 monitores:
    #   Monitor principal  → arranca en grupo 1
    #   Monitor secundario → arranca en grupo 5
    #
    # Con 1 monitor: no hace nada, arranca en grupo 1 por defecto.
    if len(qtile.screens) >= 2:
        qtile.screens[0].set_group(qtile.groups_map["1"])
        qtile.screens[1].set_group(qtile.groups_map["5"])


# Necesario para que apps Java (IntelliJ, etc.) funcionen bien con un WM
wmname = "LG3D"
