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

esto funciona en ubuntu
sudo snap install rmpc

# en debian use:
# descargar desde el gihub https://github.com/mierak/rmpc/releases/tag/v0.11.0
# Descomprimir:
tar -xzf rmpc-v0.11.0-x86_64-unknown-linux-gnu.tar.gz

# Moverlo al repositorio correcto:

```

```bash
#instalacion debian por .tar.gz

Tienes estos archivos:

completions/
man/
rmpc   ← este es el ejecutable
1️⃣ Mover el binario al sistema

Lo normal es mover rmpc a /usr/local/bin para que quede disponible globalmente:

sudo mv rmpc /usr/local/bin/

Luego dale permisos por si acaso:

sudo chmod +x /usr/local/bin/rmpc

Verifica que funciona:

rmpc --version

Si muestra la versión → listo ✅

2️⃣ (Opcional) Instalar el manual

Si quieres poder hacer:

man rmpc

Mueve la carpeta man:

sudo cp -r man/* /usr/local/share/man/
sudo mandb
3️⃣ (Opcional) Autocompletado (si usas zsh)

Como sé que usas zsh 👀

Copia el autocompletado:

sudo cp completions/_rmpc /usr/local/share/zsh/site-functions/

Luego reinicia la terminal o ejecuta:

autoload -Uz compinit && compinit
```

```bash
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

#Enlace simbolico para la conf de mpd
ln -s ~/dotfiles/mpd/mpd.conf ~/.config/mpd/mpd.conf

#Revisar
ls -la ~/.config/mpd

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
