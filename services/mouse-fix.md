# Fix Mouse instalacion service

-- simbolic link to

```bash

ln -s ${HOME}/dotfiles/services/mouse-fix.service  ~/.config/systemd/user/mouse-fix.service

```

## activacion del Deamon

```bash
systemctl --user daemon-reload
systemctl --user enable mouse-fix.service
systemctl --user start mouse-fix.service

```

Esperado

```bash
Created symlink '/home/jhonayo/.config/systemd/user/default.target.wants/mouse-fix.service' → '/home/jhonayo/dotfiles/services/mouse-fix.service'.
```

## verificar

Después de reiniciar:

```bash
systemctl --user status mouse-fix.service
```

Y para ver logs:

```bash
journalctl --user -u mouse-fix.service
```

Deberías ver algo como:

```bash
[mouse-fix] Esperando X11...
[mouse-fix] Buscando dispositivo...
[mouse-fix] Dispositivo encontrado con ID 18
[mouse-fix] Remapeo aplicado correctamente.bash
```
