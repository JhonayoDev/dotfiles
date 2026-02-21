#!/usr/bin/env python3
"""
volume-control.py
Escucha el dispositivo físico del mouse (Logitech MX Master 3S) directamente
y controla el volumen via pactl. No depende de logid para esta función.

Botones configurados:
  BTN_EXTRA  (0x56 / botón superior) → subir volumen
  BTN_SIDE   (0x53 / botón inferior) → bajar volumen
  BTN_FORWARD                        → disponible para expansión (ej: dmenu)

Requisitos:
  sudo apt install python3-evdev pulseaudio-utils
  sudo usermod -aG input $USER  (+ cerrar/abrir sesión)
"""

import subprocess
import sys
import time

print("VERSION NUEVA DEL SCRIPT")
try:
    import evdev
    from evdev import InputDevice, ecodes, list_devices
except ImportError:
    print("Error: python3-evdev no está instalado.")
    print("       sudo apt install python3-evdev")
    sys.exit(1)

# ── Configuración ─────────────────────────────────────────────────────────────
# DEVICE_NAME = "LogiOps Virtual Input"
DEVICE_NAME = "Logitech MX Master 3S"
VOLUME_STEP = "5%"
RETRY_DELAY = 3
MAX_RETRIES = 20


# ── Acciones por botón ────────────────────────────────────────────────────────
def volume_up():
    subprocess.run(
        ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"+{VOLUME_STEP}"], check=False
    )


def volume_down():
    subprocess.run(
        ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"-{VOLUME_STEP}"], check=False
    )


def btn_forward():
    """BTN_FORWARD — disponible para expansión (ej: lanzar dmenu, cambiar workspace)."""
    pass  # subprocess.run(["dmenu_run"], check=False)


# ── Mapa de botones ───────────────────────────────────────────────────────────
BUTTON_ACTIONS = {
    ecodes.BTN_EXTRA: volume_up,
    ecodes.BTN_SIDE: volume_down,
    #    ecodes.BTN_FORWARD: btn_forward,
}
# BUTTON_ACTIONS = {
#    ecodes.KEY_VOLUMEUP: volume_up,
#    ecodes.KEY_VOLUMEDOWN: volume_down,
# }


# ── Buscar dispositivo por nombre ─────────────────────────────────────────────
def find_device(name: str) -> InputDevice | None:
    for path in list_devices():
        try:
            dev = InputDevice(path)
            if dev.name == name:
                return dev
        except Exception:
            continue
    return None


def wait_for_device(name: str) -> InputDevice:
    for attempt in range(1, MAX_RETRIES + 1):
        dev = find_device(name)
        if dev:
            print(f"[OK] Dispositivo encontrado: {dev.name} ({dev.path})")
            return dev
        print(f"[{attempt}/{MAX_RETRIES}] Esperando '{name}'...")
        time.sleep(RETRY_DELAY)

    print(f"[ERROR] No se encontró '{name}' después de {MAX_RETRIES} intentos.")
    sys.exit(1)


# ── Loop principal ────────────────────────────────────────────────────────────
def main():
    # import os

    # print("ENV:", os.environ)
    print("VERSION NUEVA DEL SCRIPT")
    print(f"volume-control: buscando '{DEVICE_NAME}'...")
    device = wait_for_device(DEVICE_NAME)

    print("Escuchando botones del mouse. Ctrl+C para salir.")
    try:
        for event in device.read_loop():
            if event.type != ecodes.EV_KEY:
                continue
            if event.value != 1:  # solo key down
                continue

            action = BUTTON_ACTIONS.get(event.code)
            if action:
                action()

    except OSError as e:
        print(f"[WARN] Dispositivo perdido: {e}")
        print("Reiniciando en 5 segundos...")
        time.sleep(5)
        main()

    except KeyboardInterrupt:
        print("\nDetenido.")
        sys.exit(0)


if __name__ == "__main__":
    main()
