# FAQ YouTube liviano (MacBook 2014)

Todo lo afinado para no fundir el equipo: Firefox .deb + mpv + qutebrowser + FreeTube.
Guía paso a paso en `README.md` (sección afinado térmico).

## Reproducir

```bash
yt "URL"                  # un video (H.264 VA-API si hay, si no 480p)
yt -f "URL"               # lo mismo en fondo (detach, terminal libre)
ver-listas                # elige lista con fzf, suena en fondo, terminal libre
ver-listas -s             # lo mismo en aleatorio
mpv ~/Música/listas-youtube/mi-mix-radio.m3u
```

## Crear listas

```bash
crear-lista "URL" "nombre"  # directo
crear-lista                 # guiado: pide link y nombre (vacío = auto)
YT_LIMITE=200 crear-lista "URL" "nombre"  # tope distinto de 400
```
Guarda `.m3u` + `.txt` juntos en `~/Música/listas-youtube/`.
Tipos de link: playlist `list=PL...`, mix `list=RD...` (foto del momento),
video suelto, canal. Los privados no se pueden extraer.

## Atajos mpv (ventana enfocada)

| Tecla | Hace |
|---|---|
| `q` | salir |
| `espacio` | pausa / play |
| `f` | pantalla completa |
| `>` / `<` | siguiente / anterior (en playlists) |
| `←/→` | ±5s, `↑/↓` ±1min |
| `9` / `0`, `m` | volumen / mute |
| `o` | muestra qué suena |
| `M` (mayús) | alterna **mono ↔ estéreo** (temas paneados raros) |

`ver-listas` usa `--no-terminal`: la consola queda libre, el control es con
la ventana. Parar desde terminal: `pkill mpv`.

## Volumen

| Tecla | Hace |
|---|---|
| `F12` / `F11` | subir / bajar 2% el volumen general |
| `Super+F12` / `Super+F11` | ajuste fino: 1% |
| `F10` | mute |
| `Super+Shift+a` | **volumen por aplicación** (mpv, Firefox, etc.) |
| `Super+Shift+c` | AirPods: micrófono para llamadas ⇄ música (A2DP) |

En modo llamada el micro va por HFP y estos AirPods solo negocian CVSD (8 kHz),
así que suena opaco; para mejor calidad usa el micro interno del Mac y deja los
AirPods en A2DP (modo música).

`Super+Shift+a` lista lo que está sonando; al elegir una app se abre un
**slider** (zenity): arrastra o usa flechas para 1% de precisión. Se puede dejar
mpv de fondo al 20% y la clase al 100%. Al aplicar vuelve a la lista (Esc sale).
Con una app seleccionada, `Alt+M` la silencia/activa sin abrir el slider.
CLI: `pactl set-sink-input-volume <id> 30%` (id vía
`pactl -f json list sink-inputs | jq`).

## qutebrowser (mini)

`o`/`O` abrir, `b` marcadores, `f`/`F` seguir link, `M` video a mpv,
`,m` link a mpv, `d`/`u` cerrar/reabrir tab, `/` buscar, `:q` salir.

## Si algo falla

* **HTTP 429 / "not available" en todo:** baneo temporal de IP por exceso de
  requests. No reintentar en loop; esperar ~30 min. Las listas guardadas no se pierden.
* **"Sign in to confirm you're not a bot":** re-loguearse en YouTube en Firefox;
  mpv usa sus cookies (ruta en `mpv.conf`).
* **Se escucha AV1 al 50% CPU:** el video no tiene H.264; el conf ya baja a 480p
  solo. Verificar con la línea `(...)` al abrir.
* **Cantante en un oído, música en otro:** es el upload paneado, no tu equipo.
  Tecla `M` para mono, o `mpv --audio-channels=mono URL`.
* **`No key binding found`:** teclas de qutebrowser en ventana mpv (no aplican).
* **FreeTube no abre Mix `RD`:** limitación real; extraer foto con `crear-lista`.

## Archivos

* `mpv/.config/mpv/mpv.conf` — formato, VA-API, cookies
* `mpv/.config/mpv/input.conf` — tecla `M` mono/estéreo
* `qutebrowser/.config/qutebrowser/config.py` — atajos (`M`, `,m`, `b`)
* `scripts/yt-lista.sh` — extractor (tope `YT_LIMITE`, default 400)
* alias `yt` + funciones `crear-lista`/`ver-listas` en `zsh/.zshrc`
* Datos locales (NO van al repo): `~/.config/FreeTube`, `~/Música/listas-youtube`
