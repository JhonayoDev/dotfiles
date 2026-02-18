# Sesión: MPD + rmpc — Registro completo

**Fecha:** 2026-02-18  
**Estado:** En progreso — pendiente aplicar symlinks y commit

---

## ¿Qué se instaló?

| Herramienta  | Método                        | Notas                                                |
| ------------ | ----------------------------- | ---------------------------------------------------- |
| `mpd`        | `sudo apt install mpd mpc`    | Servicio global deshabilitado, corre en modo usuario |
| `mpc`        | junto con mpd                 | Cliente CLI para scripts/diagnóstico                 |
| `rmpc`       | `sudo snap install rmpc`      | GitHub no accesible, se usó snap                     |
| `cifs-utils` | `sudo apt install cifs-utils` | Para montaje SMB                                     |
| `smbclient`  | `sudo apt install smbclient`  | Para explorar shares del servidor                    |

---

## Estructura en dotfiles (objetivo)

```
~/dotfiles/
├── .gitignore                        ← excluye credenciales y archivos runtime
├── mpd/
│   └── mpd.conf                      ← config de MPD (apunta a mount SMB)
├── rmpc/
│   ├── config.ron                    ← config general + keybinds
│   └── themes/
│       └── custom.ron                ← tema visual (colores, layout)
└── smb/
    ├── README.md                     ← guía completa de montaje SMB
    └── .smbcredentials.example       ← plantilla SIN contraseña (versionada)
```

### Symlinks a crear

```bash
~/.config/mpd   → ~/dotfiles/mpd
~/.config/rmpc  → ~/dotfiles/rmpc
```

### Archivo real de credenciales (NUNCA en repo)

```
~/.smbcredentials    ← solo existe en el sistema local
```

---

## Comandos ejecutados en la sesión

```bash
# Instalación
sudo apt install mpd mpc cifs-utils smbclient
sudo systemctl disable --now mpd
sudo snap install rmpc

# Directorios
mkdir -p ~/.config/mpd ~/.local/share/mpd/playlists ~/Music/servidor

# Explorar servidor
smbclient -L //192.168.0.25 -U jhonayo

# Credenciales SMB
cat > ~/.smbcredentials << EOF
username=jhonayo
password=***
domain=WORKGROUP
EOF
chmod 600 ~/.smbcredentials

# Montaje SMB
sudo mount -t cifs //192.168.0.25/Datos_main ~/Music/servidor \
  -o credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g)

# Configurar MPD y reindexar
sed -i 's|~/Music|~/Music/servidor/Musica_Itunes/Music|' ~/.config/mpd/mpd.conf
mpd --kill && mpd ~/.config/mpd/mpd.conf
mpc update
mpc listall | wc -l
```

---

## Servidor de música

| Dato             | Valor                                  |
| ---------------- | -------------------------------------- |
| IP local         | `192.168.0.25`                         |
| Hostname         | `ideaserver`                           |
| Share SMB        | `Datos_main`                           |
| Ruta en servidor | `/srv/datos/Musica_Itunes/Music`       |
| Mount local      | `~/Music/servidor/Musica_Itunes/Music` |
| Acceso remoto    | Tailscale VPN (misma IP)               |

### Shares disponibles

| Share             | Contenido                       |
| ----------------- | ------------------------------- |
| `Datos_main`      | Datos principales — música aquí |
| `Datos_media`     | Media general                   |
| `Datos_media_usb` | USB externo                     |
| `Komga`           | Manga y libros                  |

---

## Montaje SMB — referencia rápida

```bash
# Montar (manual)
sudo mount -t cifs //192.168.0.25/Datos_main ~/Music/servidor \
  -o credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g),iocharset=utf8

# Desmontar
sudo umount ~/Music/servidor

# Desmontar forzado
sudo umount -l ~/Music/servidor

# Hacer permanente (agregar a fstab)
echo "//192.168.0.25/Datos_main $HOME/Music/servidor cifs credentials=$HOME/.smbcredentials,uid=$(id -u),gid=$(id -g),iocharset=utf8,_netdev 0 0" \
  | sudo tee -a /etc/fstab
sudo mount -a    # probar sin reiniciar

# Quitar permanente
sudo nano /etc/fstab    # eliminar la línea de Datos_main
sudo umount ~/Music/servidor

# Verificar si está montado
df -h | grep servidor
```

---

## Comandos MPD diarios

```bash
mpd ~/.config/mpd/mpd.conf   # arrancar
mpd --kill                    # detener
mpc update                    # reindexar biblioteca
mpc status                    # estado actual
mpc listall | wc -l           # contar canciones
rmpc                          # abrir cliente TUI
```

---

## Atajos rmpc

| Tecla           | Acción                                |
| --------------- | ------------------------------------- |
| `Tab` / `S-Tab` | Siguiente / anterior pestaña          |
| `1` `2` `3` `4` | Queue / Playlists / Library / Artists |
| `F`             | Búsqueda                              |
| `p`             | Pausar / reanudar                     |
| `>` / `<`       | Siguiente / anterior canción          |
| `f` / `b`       | Adelantar / retroceder                |
| `.` / `,`       | Subir / bajar volumen                 |
| `a` / `A`       | Agregar canción / agregar todo        |
| `d` / `D`       | Eliminar canción / vaciar cola        |
| `C-s`           | Guardar cola como playlist            |
| `z x c v`       | Repeat / Random / Consume / Single    |
| `u`             | Actualizar base de datos              |
| `I`             | Info de canción actual                |
| `?`             | Ayuda                                 |
| `q`             | Salir                                 |

---

## Pasos pendientes en el sistema

```bash
# 1. Mover configs reales a dotfiles
mkdir -p ~/dotfiles/mpd ~/dotfiles/rmpc/themes ~/dotfiles/smb

mv ~/.config/mpd/mpd.conf ~/dotfiles/mpd/mpd.conf

# 2. Crear symlinks
rm -rf ~/.config/mpd ~/.config/rmpc
ln -sfn ~/dotfiles/mpd  ~/.config/mpd
ln -sfn ~/dotfiles/rmpc ~/.config/rmpc

# 3. Verificar symlinks
ls -la ~/.config/mpd
ls -la ~/.config/rmpc

# 4. Copiar archivos SMB a dotfiles
cp smb-README.md           ~/dotfiles/smb/README.md
cp .smbcredentials.example ~/dotfiles/smb/.smbcredentials.example
cp dotfiles-gitignore      ~/dotfiles/.gitignore

# 5. Aplicar config visual rmpc
cp config.ron   ~/dotfiles/rmpc/config.ron
cp custom.ron   ~/dotfiles/rmpc/themes/custom.ron

# 6. Reiniciar MPD y verificar
mpd --kill && mpd ~/.config/mpd/mpd.conf
mpc status && rmpc

# 7. Commit
cd ~/dotfiles
git add -A
git commit -m "feat: agregar MPD, rmpc y configuración SMB"
git push
```

---

## Archivos generados en esta sesión

| Archivo                       | Destino en dotfiles             | Descripción                                      |
| ----------------------------- | ------------------------------- | ------------------------------------------------ |
| `install.sh`                  | `~/dotfiles/scripts/install.sh` | Script de instalación actualizado (12 secciones) |
| `backup.sh`                   | `~/dotfiles/scripts/backup.sh`  | Script de backup actualizado                     |
| `smb/README.md`               | `~/dotfiles/smb/README.md`      | Guía completa SMB con todos los comandos         |
| `smb/.smbcredentials.example` | `~/dotfiles/smb/`               | Plantilla de credenciales sin password           |
| `.gitignore`                  | `~/dotfiles/.gitignore`         | Excluye credenciales y archivos runtime          |

---

## Decisiones pendientes

| Decisión                                  | Estado                           |
| ----------------------------------------- | -------------------------------- |
| Mover configs a dotfiles y crear symlinks | ⏳ Siguiente paso                |
| Aplicar config visual rmpc                | ⏳ Después de symlinks           |
| Montaje SMB permanente en `/etc/fstab`    | ⏳ Después de probar estabilidad |
| Commit y push al repo                     | ⏳ Al final de todo              |

---

## Pasos previos a ejecutar install.sh (máquina nueva)

Antes de clonar dotfiles y ejecutar el script, hay pasos manuales que el script **no puede hacer** porque son datos personales.

### 1. Instalar git mínimo

```bash
sudo apt install git
```

### 2. Configurar identidad git

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"
```

### 3. Generar clave SSH para GitHub

```bash
ssh-keygen -t ed25519 -C "tu@email.com"
# Presionar Enter en todas las preguntas (o agregar passphrase si se prefiere)
```

### 4. Agregar la clave pública a GitHub

```bash
cat ~/.ssh/id_ed25519.pub
# Copiar el output completo
```

Luego en GitHub: **Settings → SSH and GPG keys → New SSH key** → pegar la clave.

Verificar que funciona:

```bash
ssh -T git@github.com
# Debe responder: Hi TU_USUARIO! You've successfully authenticated...
```

### 5. Clonar dotfiles

```bash
git clone git@github.com:TU_USUARIO/dotfiles.git ~/dotfiles
```

### 6. Ejecutar el script de instalación

```bash
zsh ~/dotfiles/scripts/install.sh
```

### 7. Después del script — configurar credenciales SMB

```bash
cp ~/dotfiles/smb/.smbcredentials.example ~/.smbcredentials
nano ~/.smbcredentials      # rellenar username y password
chmod 600 ~/.smbcredentials
```

### 8. Crear symlinks snap de rmpc (si se instala vía snap)

```bash
sudo cp ~/dotfiles/rmpc/config.ron /var/snap/rmpc/common/config.ron
sudo mkdir -p /var/snap/rmpc/common/themes
sudo ln -sfn ~/dotfiles/rmpc/themes/custom.ron /var/snap/rmpc/common/themes/custom.ron
```

> **Nota:** rmpc instalado via snap ignora `~/.config/rmpc/` y lee desde
> `/var/snap/rmpc/common/`. El `config.ron` se copia y el tema se enlaza
> con symlink para que los cambios en dotfiles se reflejen automáticamente.
