import subprocess
import re


def get_default_sink():
    try:
        result = subprocess.run(
            ["pactl", "get-default-sink"], capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def is_headphone_connected():
    """Detecta auriculares jack via amixer"""
    try:
        result = subprocess.run(
            ["amixer", "-c", "0", "contents"],
            capture_output=True,
            text=True,
            check=True,
        )
        match = re.search(
            r"Headphone Jack.*?:\s*values=(\w+)", result.stdout, re.DOTALL
        )
        if match:
            return match.group(1) == "on"
    except subprocess.CalledProcessError:
        pass
    return False


def is_bluetooth_sink():
    """Detecta si el sink activo es bluetooth"""
    sink = get_default_sink()
    if not sink:
        return False
    return "bluetooth" in sink.lower() or "bluez" in sink.lower()


def get_volume_info():
    sink = get_default_sink()
    if not sink:
        return 0, False
    try:
        v = subprocess.run(
            ["pactl", "get-sink-volume", sink],
            capture_output=True,
            text=True,
            check=True,
        )
        m = subprocess.run(
            ["pactl", "get-sink-mute", sink],
            capture_output=True,
            text=True,
            check=True,
        )
        volume_match = re.search(r"/\s*(\d+)%", v.stdout)
        volume = int(volume_match.group(1)) if volume_match else 0
        muted = "yes" in m.stdout.lower() or "sí" in m.stdout.lower()
        return volume, muted
    except subprocess.CalledProcessError:
        return 0, False


def get_volume_widget_text():
    volume, muted = get_volume_info()

    if is_bluetooth_sink():
        device_icon = "󰋋"
    elif is_headphone_connected():
        device_icon = "󰙈"
    else:
        device_icon = "󰓃"

    if muted:
        return f"{device_icon} 󰝟"
    elif volume == 0:
        return f"{device_icon} 󰕿"
    elif volume < 40:
        return f"{device_icon} {volume}%"
    else:
        return f"{device_icon} {volume}%"
