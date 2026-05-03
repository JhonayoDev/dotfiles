def get_battery_text():
    try:
        capacity = int(open("/sys/class/power_supply/BAT0/capacity").read().strip())
        status = open("/sys/class/power_supply/BAT0/status").read().strip()

        if status == "Charging":
            icon = "󰂄"
        elif capacity >= 80:
            icon = "󰁹"
        elif capacity >= 60:
            icon = "󰂁"
        elif capacity >= 40:
            icon = "󰁾"
        elif capacity >= 20:
            icon = "󰁻"
        else:
            icon = "󰂎"

        return f"{icon} {capacity}%"
    except Exception:
        return "󰂑 ?%"
