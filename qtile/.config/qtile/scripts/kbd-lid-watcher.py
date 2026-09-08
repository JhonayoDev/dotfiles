#!/usr/bin/env python3
# kbd-lid-watcher.py — apaga backlight del teclado al cerrar tapa (modo dock)
# Opción A: escucha Lid Switch via evdev (instantáneo, sin polling ni root)
# Comportamiento:
#   - Lid closed (1) -> guarda brillo actual en /tmp/kbd_backlight_last y pone 0%
#   - Lid open (0)   -> no restaura (respeta "por defecto apagado", subes manual con F5/F6)
#                    -> cambia RESTORE_ON_OPEN=True si quieres que restaure al abrir
# Requiere: python3-evdev, usuario en grupo 'input' (ya lo estás), device smc::kbd_backlight
import os
import subprocess
import sys
import time

DEVICE = "smc::kbd_backlight"
TMP_LAST = "/tmp/kbd_backlight_last"
TMP_LID_SAVE = "/tmp/kbd_backlight_lid_save"
RESTORE_ON_OPEN = False  # True = restaura último brillo al abrir tapa

def get_brightness():
    try:
        out = subprocess.check_output(["brightnessctl", "--device", DEVICE, "get"], text=True).strip()
        return int(out)
    except Exception:
        return None

def get_max():
    try:
        out = subprocess.check_output(["brightnessctl", "--device", DEVICE, "max"], text=True).strip()
        return int(out)
    except Exception:
        return 255

def set_brightness_pct(pct):
    try:
        subprocess.run(["brightnessctl", "--device", DEVICE, "set", f"{pct}%", "-q"], check=False)
    except Exception as e:
        print(f"[kbd-lid-watcher] error set {pct}%: {e}", file=sys.stderr)

def pct_from_current():
    cur = get_brightness()
    mx = get_max()
    if cur is None or mx == 0:
        return 0
    return int((cur * 100 + mx // 2) / mx)

def find_lid_device():
    try:
        import evdev
    except ImportError:
        print("[kbd-lid-watcher] python3-evdev no instalado (sudo apt install python3-evdev)", file=sys.stderr)
        sys.exit(1)

    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if dev.name == "Lid Switch":
            return dev
    # fallback a event0
    try:
        return evdev.InputDevice("/dev/input/event0")
    except Exception:
        return None

def handle_lid_closed():
    cur = get_brightness()
    pct = pct_from_current()
    print(f"[kbd-lid-watcher] Lid closed, current {pct}% ({cur}) -> apagando", flush=True)
    if cur is not None and cur > 0:
        # guarda para posible restore (y para que kbd-backlight.sh toggle lo use)
        try:
            with open(TMP_LAST, "w") as f:
                f.write(str(pct))
            with open(TMP_LID_SAVE, "w") as f:
                f.write(str(pct))
        except Exception:
            pass
        set_brightness_pct(0)

def handle_lid_open():
    print("[kbd-lid-watcher] Lid open", flush=True)
    if RESTORE_ON_OPEN:
        # restaura el que había antes de cerrar
        last = None
        for p in (TMP_LID_SAVE, TMP_LAST):
            if os.path.exists(p):
                try:
                    last = int(open(p).read().strip())
                    break
                except Exception:
                    continue
        if last is None:
            last = 50
        if last == 0:
            last = 50
        print(f"[kbd-lid-watcher] restaurando {last}%", flush=True)
        set_brightness_pct(last)
    else:
        # respeta "por defecto apagado" — no restaura, el usuario sube con F5/F6 si quiere
        pass

def main():
    # si el device no existe, salir
    if get_brightness() is None:
        print(f"[kbd-lid-watcher] device {DEVICE} no disponible, saliendo", file=sys.stderr)
        sys.exit(0)

    dev = find_lid_device()
    if dev is None:
        print("[kbd-lid-watcher] Lid Switch no encontrado", file=sys.stderr)
        sys.exit(1)

    print(f"[kbd-lid-watcher] escuchando {dev.path} ({dev.name}) -> {DEVICE}, RESTORE_ON_OPEN={RESTORE_ON_OPEN}", flush=True)

    # chequeo inicial: si ya está cerrada al iniciar, apaga
    try:
        with open("/proc/acpi/button/lid/LID0/state") as f:
            if "closed" in f.read():
                handle_lid_closed()
    except Exception:
        pass

    # loop evdev (bloqueante, reconecta si falla)
    import evdev
    while True:
        try:
            for event in dev.read_loop():
                # EV_SW = 5, SW_LID = 0, value 1=closed, 0=open
                if event.type == evdev.ecodes.EV_SW and event.code == evdev.ecodes.SW_LID:
                    if event.value == 1:
                        handle_lid_closed()
                    elif event.value == 0:
                        handle_lid_open()
        except OSError as e:
            print(f"[kbd-lid-watcher] device desconectado: {e}, reintentando en 2s", file=sys.stderr)
            time.sleep(2)
            dev = find_lid_device()
            if dev is None:
                time.sleep(2)
                continue
        except Exception as e:
            print(f"[kbd-lid-watcher] error: {e}", file=sys.stderr)
            time.sleep(2)

if __name__ == "__main__":
    main()
