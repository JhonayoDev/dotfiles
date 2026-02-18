# Montaje SMB — Servidor de música

Servidor: `192.168.0.25` (ideaserver)
Share: `Datos_main`
Ruta en servidor: `/srv/datos/Musica_Itunes/Music`
Acceso: red local + Tailscale VPN

---

## 1. Configurar credenciales (solo primera vez)

```bash
# Copiar la plantilla
cp ~/dotfiles/smb/.smbcredentials.example ~/.smbcredentials

# Rellenar con tus datos
nano ~/.smbcredentials
# → username=jhonayo
# → password=TU_CONTRASEÑA_AQUI
# → domain=WORKGROUP

# Proteger el archivo (solo lectura para tu usuario)
chmod 600 ~/.smbcredentials
```

> ⚠️ `~/.smbcredentials` nunca se sube al repo git.
> Solo la plantilla `.smbcredentials.example` (sin contraseña) está versionada.

---

## 2. Montar el servidor (manual, sesión actual)

```bash
mkdir -p ~/Music/servidor

sudo mount -t cifs //192.168.0.25/Datos_main ~/Music/servidor \
  -o credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

Verificar que montó:
```bash
ls ~/Music/servidor
# Debe mostrar: media  Musica_Itunes  respaldos
```

---

## 3. Desmontar

```bash
sudo umount ~/Music/servidor
```

Si está ocupado:
```bash
sudo umount -l ~/Music/servidor   # lazy unmount
```

---

## 4. Montaje permanente al boot (fstab)

```bash
# Agregar entrada a /etc/fstab
echo "//192.168.0.25/Datos_main $HOME/Music/servidor cifs credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g),iocharset=utf8,_netdev 0 0" | sudo tee -a /etc/fstab
```

> `_netdev` le indica al sistema que espere a que la red esté lista antes de montar.

Verificar sin reiniciar:
```bash
sudo mount -a
```

---

## 5. Deshacer el montaje permanente (quitar de fstab)

```bash
# Ver el contenido actual de fstab
cat /etc/fstab

# Editar y eliminar la línea de Datos_main
sudo nano /etc/fstab

# Desmontar si está montado
sudo umount ~/Music/servidor
```

---

## 6. Cambiar ubicación de la música en el servidor

Si la música se mueve a otra ruta en el servidor, editar `mpd.conf`:

```bash
nano ~/dotfiles/mpd/mpd.conf
# Cambiar music_directory a la nueva ruta

# Reiniciar MPD y reindexar
mpd --kill
mpd ~/.config/mpd/mpd.conf
mpc update
```

---

## 7. Cambiar de share o servidor

```bash
# Desmontar primero
sudo umount ~/Music/servidor

# Editar fstab si el montaje es permanente
sudo nano /etc/fstab

# Montar el nuevo share
sudo mount -t cifs //NUEVA_IP/NUEVO_SHARE ~/Music/servidor \
  -o credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

---

## 8. Ver shares disponibles en el servidor

```bash
smbclient -L //192.168.0.25 -U jhonayo
# Shares actuales:
#   Datos_media      → media general
#   Datos_media_usb  → USB externo
#   Datos_main       → datos principales (música aquí)
#   Komga            → manga y libros
```

---

## Referencia rápida

| Acción | Comando |
|---|---|
| Montar | `sudo mount -t cifs //192.168.0.25/Datos_main ~/Music/servidor -o credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g)` |
| Desmontar | `sudo umount ~/Music/servidor` |
| Verificar mount | `df -h \| grep servidor` |
| Ver shares | `smbclient -L //192.168.0.25 -U jhonayo` |
| Hacer permanente | Agregar a `/etc/fstab` (ver sección 4) |
| Quitar permanente | Editar `/etc/fstab` y borrar la línea (ver sección 5) |
