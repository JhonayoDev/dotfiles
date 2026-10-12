config.load_autoconfig()

# Qutebrowser - MacBook 2014 + Qtile
# Abrir video actual en mpv (720p H.264, ver ~/.config/mpv/mpv.conf)
config.bind('M', 'spawn mpv --ytdl-format="bestvideo[height<=720]+bestaudio/best[height<=720]" {url}')
# Elegir link con hints y mandarlo a mpv
config.bind(',m', 'hint links spawn mpv --ytdl-format="bestvideo[height<=720]+bestaudio/best[height<=720]" {hint-url}')
# b = buscar en marcadores (los 74 migrados), B = abrir en tab nueva
config.bind('b', 'set-cmd-text -s :bookmark-load')
config.bind('B', 'set-cmd-text -s :bookmark-load -t')
# YouTube liviano: sin autoplay
config.set('content.autoplay', False, 'https://www.youtube.com/*')
# Bloqueo de ads/trackers (instala python3-adblock para el modo completo)
config.set('content.blocking.enabled', True)
config.set('content.blocking.method', 'both')
