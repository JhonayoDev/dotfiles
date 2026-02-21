Keyboard Layout Setup (Latam default + US toggle)
🎯 Objetivo

Iniciar siempre en Spanish (latam)

Permitir alternar manualmente a US

Funcionar en XFCE y dwm

No depender de .xprofile

Configuración limpia a nivel de Xorg

🔎 Estado inicial detectado
setxkbmap -query

Mostraba algo como:

layout: latam,us
options: grp:alt_caps_toggle

Pero:

localectl status

Mostraba:

X11 Layout: us

Esto ocurre porque localectl muestra lo registrado en systemd,
pero Xorg puede estar usando otra configuración.

✅ Solución correcta (nivel Xorg)

Crear el archivo:

/etc/X11/xorg.conf.d/00-keyboard.conf

Contenido:

Section "InputClass"
Identifier "system-keyboard"
MatchIsKeyboard "on"
Option "XkbModel" "pc105"
Option "XkbLayout" "latam,us"
Option "XkbOptions" "grp:alt_caps_toggle"
EndSection
🔄 Aplicar cambios

Cerrar sesión gráfica (logout) y volver a entrar.

No es necesario reiniciar el sistema completo.

🧪 Verificación

Después de iniciar sesión:

setxkbmap -query

Debe mostrar:

layout: latam,us

Probar:

Escribir ñ → debe funcionar

Alt + Bloq Mayús → alterna a US

Toggle nuevamente → vuelve a latam

🧠 Notas importantes
1️⃣ localectl status puede seguir mostrando:
X11 Layout: us

Eso es normal.
No afecta la configuración real de X.

2️⃣ LANG=en_US.UTF-8

Eso es el idioma del sistema, no el teclado.
Puedes dejarlo así sin problema.

3️⃣ No usar .xprofile

Ya no es necesario tener:

setxkbmap latam,us -option grp:alt_caps_toggle

Porque ahora Xorg lo configura directamente.

🧹 Limpieza realizada

Eliminado setxkbmap de ~/.xprofile

Configuración movida a /etc/X11/xorg.conf.d/

📌 Resultado final

✔ Inicia siempre en Español (latam)
✔ Toggle manual a US
✔ Funciona en XFCE
✔ Funcionará en dwm
✔ Configuración persistente
✔ Independiente del entorno gráfico

Si en el futuro algo falla, revisar:

cat /etc/X11/xorg.conf.d/00-keyboard.conf
setxkbmap -query
