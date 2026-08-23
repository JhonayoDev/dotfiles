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
RETRY_DELAY = 2
MAX_RETRIES = 0  # 0 = infinito (estable Bluetooth, sobrevive DPMS 600s)
RETRY_FOREVER = True

mode = "audio"


def run(cmd):
    subprocess.run(cmd, check=False)


def notify(title, body):
    run(["notify-send", "--replace-id=2000", "--expire-time=2000", title, body])


def get_xinput_id(name):
    try:
        out = subprocess.run(
            ["xinput", "list", "--id-only", name], capture_output=True, text=True
        ).stdout.strip()
        if out:
            return out
        # fallback: grep por nombre parcial (Bluetooth puede variar)
        out2 = subprocess.run(
            ["xinput", "list"], capture_output=True, text=True
        ).stdout
        for line in out2.splitlines():
            if name.lower() in line.lower():
                m = re.search(r"id=(\d+)", line)
                if m:
                    return m.group(1)
        return None
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
        [
            "qtile",
            "cmd-obj",
            "-o",
            "widget",
            "volume",
            "-f",
            "eval",
            "-a",
            "self.force_update()",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def set_audio_mode():
    device_id = get_xinput_id(DEVICE_NAME)
    if device_id:
        run(
            [
                "xinput",
                "set-button-map",
                device_id,
                "1",
                "2",
                "3",
                "4",
                "5",
                "6",
                "7",
                "0",
                "0",
                "10",
                "11",
                "12",
                "13",
                "14",
                "15",
                "16",
                "17",
                "18",
                "19",
                "20",
            ]
        )


def set_nav_mode():
    device_id = get_xinput_id(DEVICE_NAME)
    if device_id:
        run(
            [
                "xinput",
                "set-button-map",
                device_id,
                "1",
                "2",
                "3",
                "4",
                "5",
                "6",
                "7",
                "8",
                "9",
                "10",
                "11",
                "12",
                "13",
                "14",
                "15",
                "16",
                "17",
                "18",
                "19",
                "20",
            ]
        )


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
        notify("󰍺  Mouse", "Modo navegación")
    else:
        mode = "audio"
        set_audio_mode()
        notify("󰕾  Mouse", "Modo audio")


ACTIONS = {
    "audio": {
        ecodes.BTN_EXTRA: volume_up,
        ecodes.BTN_SIDE: volume_down,
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
    attempt = 0
    while True:
        attempt += 1
        dev = find_device(name)
        if dev:
            print(f"[OK] {dev.name} ({dev.path})", flush=True)
            return dev
        # no salir nunca si RETRY_FOREVER; espera Bluetooth reconexión tras DPMS/suspend
        if MAX_RETRIES and attempt >= MAX_RETRIES:
            print(f"[ERROR] No se encontró '{name}' tras {attempt} intentos", flush=True)
            sys.exit(1)
        # log cada 5 intentos para no spamear journal
        if attempt == 1 or attempt % 5 == 0:
            print(f"[{attempt}] Esperando '{name}'... (Bluetooth, DPMS 600s)", flush=True)
        time.sleep(RETRY_DELAY)


def event_loop(device):
    global mode
    while True:
        try:
            for event in device.read_loop():
                if event.type != ecodes.EV_KEY:
                    continue
                if event.value != 1:
                    continue
                action = ACTIONS[mode].get(event.code)
                if action:
                    try:
                        action()
                    except Exception as e:
                        print(f"[WARN] acción falló: {e}", flush=True)
        except OSError as e:
            print(f"[WARN] Dispositivo perdido: {e} — reintentando...", flush=True)
            time.sleep(2)
            # reaplica xinput tras DPMS Off (X resetea button-map)
            new_device = wait_for_device(DEVICE_NAME)
            # espera a que xinput lo vea (Bluetooth puede tardar 1-2s más que evdev)
            for _ in range(5):
                if get_xinput_id(DEVICE_NAME):
                    break
                time.sleep(1)
            try:
                if mode == "audio":
                    set_audio_mode()
                else:
                    set_nav_mode()
            except Exception as e2:
                print(f"[WARN] set_*_mode falló: {e2}", flush=True)
            # reintenta loop con nuevo device (recursión convertida a loop)
            device = new_device
            continue
        except Exception as e:
            print(f"[ERROR] loop inesperado: {e}", flush=True)
            time.sleep(2)
            device = wait_for_device(DEVICE_NAME)
            continue


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
