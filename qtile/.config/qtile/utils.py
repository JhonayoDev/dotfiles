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
