#!/bin/bash
# Tele fija — Batocera RS Groove (v1.0.0, 08/11/2026). La llama /boot/postshare.sh en cada arranque, antes del menú.
# Pedido de la persona: apaga la tele con su control para dormir y la prende a la mañana; nada tiene que reiniciarse ni
# romperse, y el mando queda lejos (nunca depender de Select + Start).
# Qué hace, SOLO si al arrancar la tele está conectada:
#   1) el núcleo toma la tele como SIEMPRE conectada (debugfs force=on) y con sus datos fijos (edid_override): al
#      prenderla, la notebook no la vuelve a leer (el 08/11 Android la leyó mal, 1024×768, y se trabó);
#   2) el aviso «la pantalla cambió» ya no reinicia el menú: tapa batocera-switch-screen-checker-delayed con
#      aviso-pantalla.sh (mount --bind, se pierde al reiniciar; el original queda guardado al lado).
# Sin tele al arrancar no hace nada: la pantalla se elige sola, como siempre.
# Consecuencia aceptada: si se desenchufa el cable con la Batocera prendida, la notebook vuelve recién al reiniciar.
# Volver atrás: borrar la llamada en /boot/postshare.sh (o esta carpeta) y reiniciar.
DIR=/userdata/system/tele-fija
LOG=/userdata/system/logs/tele-fija.log
COPIA=/userdata/system/copias-buenas/tele-samsung-edid.bin
TAPA=/usr/bin/batocera-switch-screen-checker-delayed
ahora() { TZ=America/Argentina/Buenos_Aires date '+%F %T'; }
log() { echo "$(ahora) $*" >> "$LOG"; }

H=$(ls -d /sys/class/drm/card*-HDMI-A-1 2>/dev/null | head -1)
[ -n "$H" ] || { log "no encuentro la salida HDMI-A-1: no hago nada"; exit 0; }
for i in 1 2 3 4 5 6 7 8 9 10; do [ "$(cat "$H/status")" = connected ] && break; sleep 1; done
if [ "$(cat "$H/status")" != connected ]; then log "tele no conectada al arrancar: no la fijo"; exit 0; fi

[ -d /sys/kernel/debug/dri ] || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
F=$(ls -d /sys/kernel/debug/dri/*/HDMI-A-1 2>/dev/null | head -1)
[ -n "$F" ] || { log "AVISO: no encuentro debugfs de HDMI-A-1: la tele no queda fija"; exit 0; }

if [ "$(cat "$F/force")" != on ]; then
	if [ "$(head -c 8 "$H/edid" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = 00ffffffffffff00 ] \
		&& [ "$(wc -c < "$H/edid")" -ge 128 ]; then
		mkdir -p "${COPIA%/*}"
		cmp -s "$H/edid" "$COPIA" || { cat "$H/edid" > "$COPIA.nuevo" && mv "$COPIA.nuevo" "$COPIA"; }
		origen="leídos de la tele"
	else
		origen="copia guardada"
	fi
	[ -s "$COPIA" ] || { log "AVISO: sin datos válidos de la tele: no queda fija"; exit 0; }
	if cat "$COPIA" > "$F/edid_override" && echo on > "$F/force"; then
		log "tele fija: siempre conectada, datos $origen ($(wc -c < "$COPIA") bytes)"
	else
		log "AVISO: no pude dejar la tele fija"; exit 0
	fi
fi
touch /var/run/tele-fija

# El aviso de pantalla no reinicia el menú mientras la tele esté fija.
[ -f "$DIR/checker-delayed.original" ] || cp -p "$TAPA" "$DIR/checker-delayed.original"
if ! mount | grep -q " on $TAPA "; then
	mount --bind "$DIR/aviso-pantalla.sh" "$TAPA" && log "aviso de pantalla tapado: el menú no se reinicia al prender la tele" \
		|| log "AVISO: no pude tapar el aviso de pantalla"
fi
exit 0
