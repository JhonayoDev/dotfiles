#!/usr/bin/env bash
# Arranca LibrePods esperando al watcher SNI y lo reinicia si muere.
# ksni aborta (panic) si org.kde.StatusNotifierWatcher no esta en el bus,
# y en el login snixembed --fork aun no lo habia registrado.
# Ademas, el listener D-Bus de conexiones de librepods no siempre engancha
# el dispositivo al conectarse: al detectar la transicion a conectado se
# reinicia para que la ruta de arranque lo encuentre.
set -u

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/librepods.log"
mkdir -p "$(dirname "$LOG")"

airpods_connected() {
    local path
    for path in $(busctl --system tree org.bluez 2>/dev/null \
        | grep -o '/org/bluez/hci[0-9]*/dev_[0-9A-F_]*'); do
        busctl --system get-property org.bluez "$path" org.bluez.Device1 UUIDs 2>/dev/null \
            | grep -q 74ec2172-0bad-4d01-8f77-997b2be0722a || continue
        busctl --system get-property org.bluez "$path" org.bluez.Device1 Connected 2>/dev/null \
            | grep -q true && return 0
    done
    return 1
}

attached() {
    local item
    item=$(busctl --user list 2>/dev/null \
        | awk '/StatusNotifierItem-/{print $1}' | head -1)
    [ -n "$item" ] || return 1
    busctl --user get-property "$item" /StatusNotifierItem \
        org.kde.StatusNotifierItem ToolTip 2>/dev/null | grep -q 'L: [0-9]'
}

if ! pgrep -x snixembed >/dev/null 2>&1 && command -v snixembed >/dev/null 2>&1; then
    snixembed --fork >/dev/null 2>&1
fi

for _ in $(seq 1 60); do
    busctl --user list 2>/dev/null | grep -q org.kde.StatusNotifierWatcher && break
    sleep 0.5
done

if ! busctl --user list 2>/dev/null | grep -q org.kde.StatusNotifierWatcher; then
    echo "$(date -Is) sin StatusNotifierWatcher, abortando" >>"$LOG"
    exit 1
fi

was_connected=0
while :; do
    if airpods_connected; then
        if [ "$was_connected" -eq 0 ]; then
            was_connected=1
            sleep 3
            if ! attached; then
                echo "$(date -Is) AirPods conectados sin enganchar; reiniciando librepods" >>"$LOG"
                pkill -x librepods
                sleep 2
            fi
        fi
    else
        was_connected=0
    fi

    if ! pgrep -x librepods >/dev/null 2>&1; then
        librepods --start-minimized >>"$LOG" 2>&1 &
    fi
    sleep 5
done
