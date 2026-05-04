import subprocess
from typing import Optional


def notify(
    title: str,
    message: str,
    replace_id: Optional[int] = None,
    app_name: Optional[str] = "",
    expire_time: int = 1200,
    urgency: str = "normal",
):
    """Wrapper around notify-send con soporte para replace_id."""
    cmd = ["notify-send"]
    if replace_id:
        cmd.append(f"--replace-id={replace_id}")
    if app_name:
        cmd.append(f"--app-name={app_name}")
    cmd.append(f"--urgency={urgency}")
    cmd.append(f"--expire-time={expire_time}")
    subprocess.run(cmd + [title, message], check=False)


def show_keybindings_help():
    message = """
󰘳 BASICOS
Super + Enter → Terminal
Super + e → Archivos
Super + q → Cerrar ventana
Super + f → Fullscreen

󰖲 VENTANAS
Super + h/j/k/l → Mover foco
Super + Shift + h/j/k/l → Mover ventana
Super + Ctrl + flechas → Redimensionar
Super + n → Normalizar

󰍹 SISTEMA
Super + Ctrl + r → Reload Qtile
Super + Ctrl + q → Salir

󰆍 ROFI
Super + Space → Apps
Alt + Space → Control Center

󰕾 AUDIO
Vol+/Vol- → Ajustar volumen
Mute → Silenciar

󰃠 SCREENSHOTS
Super + p → Región
Super + Shift + p → Completo
"""

    notify(
        "󰌌 Atajos Qtile",
        message,
        replace_id=9999,
        expire_time=8000,
    )
