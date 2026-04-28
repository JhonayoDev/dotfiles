#!/usr/bin/env python3
"""
mouse-buttons.py
Botones extra del Logitech MX Master 3S.

Modos:
  Audio (default): BTN_EXTRA=vol+, BTN_SIDE=vol-, BTN_FORWARD=toggle modo
  Navegación:      BTN_EXTRA=forward, BTN_SIDE=back, BTN_FORWARD=toggle modo
"""
import subprocess
import sys
import time
import re

try:
    from evdev import InputDevice, ecodes, list_devices
except ImportError:
    print("Error: python3-evdev no está instalado.")
    sys.exit(1)

DEVICE_NAME = "Logitech MX Master 3S"
VOLUME_STEP = "5%"
RETRY_DELAY = 3
MAX_RETRIES = 20

mode = "audio"


def run(cmd):
    subprocess.run(cmd, check=False)


def notify(title, body):
    run(["notify-send", "--replace-id=2000", "--expire-time=2000", title, body])


def get_xinput_id(name):
    try:
        out = subprocess.run(
            ["xinput", "list", "--id-only", name],
            capture_output=True, text=True
        ).stdout.strip()
        return out if out else None
    except Exception:
        return None


def get_volume():
    try:
        sink = subprocess.run(
            ["pactl", "get-default-sink"], capture_output=True, text=True
        ).stdout.strip()
        out = subprocess.run(
            ["pactl", "get-sink-volume", sink], capture_output=True, text=True
        ).stdout
        m = re.search(r"/\s*(\d+)%", out)
        return int(m.group(1)) if m else 0
    except Exception:
        return 0


def force_widget_update():
    subprocess.Popen(
        ["qtile", "cmd-obj", "-o", "widget", "volume", "-f", "eval", "-a", "self.force_update()"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def set_audio_mode():
    device_id = get_xinput_id(DEVICE_NAME)
    if device_id:
        run(["xinput", "set-button-map", device_id,
             "1", "2", "3", "4", "5", "6", "7", "0", "0",
             "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20"])


def set_nav_mode():
    device_id = get_xinput_id(DEVICE_NAME)
    if device_id:
        run(["xinput", "set-button-map", device_id,
             "1", "2", "3", "4", "5", "6", "7", "8", "9",
             "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20"])


def volume_up():
    run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"+{VOLUME_STEP}"])
    vol = get_volume()
    if vol > 100:
        run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", "100%"])
        vol = 100
    notify("󰕾 Volumen", f"{vol}%")
    force_widget_update()


def volume_down():
    run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"-{VOLUME_STEP}"])
    notify("󰖀 Volumen", f"{get_volume()}%")
    force_widget_update()


def toggle_mode():
    global mode
    if mode == "audio":
        mode = "nav"
        set_nav_mode()
        notify("󰍺 Mouse", "Modo navegación")
    else:
        mode = "audio"
        set_audio_mode()
        notify("󰕾 Mouse", "Modo audio")


ACTIONS = {
    "audio": {
        ecodes.BTN_EXTRA:   volume_up,
        ecodes.BTN_SIDE:    volume_down,
        ecodes.BTN_FORWARD: toggle_mode,
    },
    "nav": {
        ecodes.BTN_FORWARD: toggle_mode,
    },
}


def find_device(name):
    for path in list_devices():
        try:
            dev = InputDevice(path)
            if dev.name == name:
                return dev
        except Exception:
            continue
    return None


def wait_for_device(name):
    for attempt in range(1, MAX_RETRIES + 1):
        dev = find_device(name)
        if dev:
            print(f"[OK] {dev.name} ({dev.path})")
            return dev
        print(f"[{attempt}/{MAX_RETRIES}] Esperando '{name}'...")
        time.sleep(RETRY_DELAY)
    print(f"[ERROR] No se encontró '{name}'")
    sys.exit(1)


def event_loop(device):
    global mode
    try:
        for event in device.read_loop():
            if event.type != ecodes.EV_KEY:
                continue
            if event.value != 1:
                continue
            action = ACTIONS[mode].get(event.code)
            if action:
                action()
    except OSError as e:
        print(f"[WARN] Dispositivo perdido: {e}")
        time.sleep(5)
        new_device = wait_for_device(DEVICE_NAME)
        if mode == "audio":
            set_audio_mode()
        else:
            set_nav_mode()
        event_loop(new_device)


def main():
    global mode
    mode = "audio"
    set_audio_mode()
    notify("󰕾 Mouse", "Modo audio activado")

    print(f"mouse-buttons: buscando '{DEVICE_NAME}'...")
    device = wait_for_device(DEVICE_NAME)
    print("Escuchando botones. Ctrl+C para salir.")

    try:
        event_loop(device)
    except KeyboardInterrupt:
        print("\nDetenido.")
        sys.exit(0)


if __name__ == "__main__":
    main()
