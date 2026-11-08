#!/bin/bash
# Tele fija — Batocera RS Groove (v1.0.0, 08/11/2026). Tapa a /usr/bin/batocera-switch-screen-checker-delayed (lo monta
# tele-fija.sh con mount --bind). La regla udev 80-switch-screen.rules lo corre en cada aviso «la pantalla cambió».
# Con la tele fija (/var/run/tele-fija): no reinicia el menú; solo vuelve a poner el volumen, como el original.
# Sin la tele fija: corre el original guardado (checker-delayed.original), igual que siempre.
if [ -f /var/run/tele-fija ]; then
	echo "Tele fija: aviso de pantalla ignorado ($(TZ=America/Argentina/Buenos_Aires date +%T)); el menú sigue" \
		>> /userdata/system/logs/display.log
	(sleep 2 && VOL=$(batocera-settings-get-master audio.volume) && [ -n "${VOL}" ] && pactl list sinks short | awk '{print $2}' | while read -r sink; do pactl set-sink-volume "${sink}" "${VOL}%"; done) >/dev/null 2>/dev/null &
	exit 0
fi
exec /bin/bash /userdata/system/tele-fija/checker-delayed.original "$@"
