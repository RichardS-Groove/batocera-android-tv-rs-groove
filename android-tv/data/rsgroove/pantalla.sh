#!/system/bin/sh
# Pantalla automática — Android TV RS Groove (v1.4.1, 08/11/2026). La lanza arranque.sh en cada arranque.
# v1.4.1: log() devuelve 0 (antes «tele fija: …» venía seguido de un «AVISO: no pude dejar la tele fija» falso).
# Regla de la persona: «si está conectado el HDMI se manda por la tele; si no, por la laptop».
# Android arranca siempre en la pantalla de la notebook (sin órdenes video= del cargador: con ellas, o apagando la
# notebook antes de prender la imagen, la tele quedaba azul y rayada). Este vigilante mira cada 2 s y, cuando la tele
# está conectada, hace el cambio que se vio bien la primera vez (v1.0.0):
#   1) sonido por la tele (HDMI 0): reinicia el controlador de sonido, espera, reinicia el servicio de sonido y
#      comprueba que haya salida (en v1.0.0 arrancaban a la vez y Android quedaba mudo, sin videos);
#   2) apaga la pantalla de la notebook y reinicia la parte gráfica (~30 s): Android pasa a la tele;
#   3) cuando vuelve la imagen, comprueba otra vez el sonido.
# Si la tele se desconecta, hace lo mismo al revés (notebook y sus parlantes).
# Espera a que el cambio dure unos segundos: la tele se conecta y desconecta varias veces al prenderse.
# Freno: si cambia más de 4 veces en 5 minutos, deja todo como está y lo anota.
# Tele fija (v1.4.0, pedido de la persona: apaga la tele con su control para dormir y la prende a la mañana, sin mando
# a mano): con Android ya en la tele, el núcleo toma la tele como SIEMPRE conectada (debugfs force=on) y con sus datos
# fijos (edid_override). Así, al prender la tele, Android no la vuelve a leer: el 08/11 la leyó mal (1024×768) y se
# trabó. Datos: los que da la tele en ese momento si son válidos (y se guardan), si no la copia tele-samsung-edid.bin.
# Consecuencia aceptada: si se desenchufa el cable con Android prendido, la notebook vuelve recién al reiniciar.
# Uso: pantalla.sh            vigila (lo normal)
#      pantalla.sh --mirar    solo dice qué haría, sin cambiar nada
# Registro: /data/rsgroove/pantalla.log
D=/data/rsgroove
LOG=$D/pantalla.log
MIRAR=""; [ "$1" = "--mirar" ] && MIRAR=1
ahora() { date '+%F %T'; }
log() { echo "$(ahora) $*" >> $LOG; [ -n "$MIRAR" ] && echo "$*"; return 0; }   # 0 siempre: si no, «a && log || log AVISO» anotaba un AVISO falso

HDMI=$(ls -d /sys/class/drm/card*-HDMI-A-1 2>/dev/null | head -1)
EDP=$(ls -d /sys/class/drm/card*-eDP-1 2>/dev/null | head -1)
if [ -z "$HDMI" ] || [ -z "$EDP" ]; then log "no encuentro las salidas HDMI-A-1 y eDP-1: no hago nada"; exit 0; fi

tele_conectada() { [ "$(cat $HDMI/status)" = connected ]; }
# La pantalla de la notebook siempre está; si figura desconectada es porque la apagamos -> Android está en la tele.
en_la_tele() { [ "$(cat $EDP/status)" != connected ]; }
estado() { if en_la_tele; then echo tele; else echo notebook; fi; }

# Sonido de la tele: el pin HDMI con monitor (eld#2.N) -> dispositivo de la placa (HDMI 0..3 = 3, 7, 8, 9).
pcm_tele() {
	for e in /proc/asound/card0/eld#*; do
		grep -q "monitor_present[[:space:]]*1" "$e" 2>/dev/null || continue
		case "${e##*.}" in 1) echo pcmC0D7p ;; 2) echo pcmC0D8p ;; 3) echo pcmC0D9p ;; *) echo pcmC0D3p ;; esac
		return
	done
	echo pcmC0D3p
}
hay_salida_de_sonido() { dumpsys media.audio_flinger 2>/dev/null | grep -q "^Output thread"; }
asegurar_sonido() {  # si el servicio de sonido quedó sin salida, se reinicia (hasta 3 veces)
	for i in 1 2 3; do
		hay_salida_de_sonido && { log "sonido por $(getprop hal.audio.out): salida abierta"; return; }
		setprop ctl.restart audioserver; sleep 5
	done
	hay_salida_de_sonido && log "sonido por $(getprop hal.audio.out): salida abierta" \
		|| log "AVISO: el sonido no abrió salida por $(getprop hal.audio.out)"
}
sonido_por() {  # $1 = dispositivo; en orden: controlador, esperar, servicio de sonido, comprobar
	# El controlador principal IGNORA las salidas HDMI («ignore pcmC0D3p») salvo con hal.audio.primary.hdmi=1:
	# sin esto Android quedaba sin ninguna salida de sonido y las apps decían «formato de video no soportado».
	case "$1" in pcmC0D0p) setprop hal.audio.primary.hdmi 0 ;; *) setprop hal.audio.primary.hdmi 1 ;; esac
	setprop hal.audio.out "$1"; setprop hal.audio.out.speaker "$1"
	setprop ctl.restart vendor.audio-hal
	i=0; until [ "$(getprop init.svc.vendor.audio-hal)" = running ] || [ "$i" -ge 20 ]; do sleep 1; i=$((i+1)); done
	sleep 2
	setprop ctl.restart audioserver; sleep 5
	asegurar_sonido
}

cambiar() {  # $1 = tele | notebook
	if [ "$1" = tele ]; then A=$(pcm_tele); else A=pcmC0D0p; fi
	log "pantalla -> $1 (sonido por $A)"
	sonido_por "$A"
	if [ "$1" = tele ]; then echo off > $EDP/status; else echo detect > $EDP/status; fi
	setprop ctl.restart vendor.hwcomposer-2-4   # reinicia también SurfaceFlinger y la interfaz (onrestart)
	sleep 40                                     # tiempo para que vuelva la imagen
	asegurar_sonido
}

EDID_COPIA=$D/tele-samsung-edid.bin
fijar_tele() {  # tele «siempre conectada» y con datos fijos (solo con Android ya en la tele)
	[ -d /sys/kernel/debug/dri ] || mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
	F=$(ls -d /sys/kernel/debug/dri/*/HDMI-A-1 2>/dev/null | head -1)
	[ -n "$F" ] || { log "AVISO: no encuentro debugfs de HDMI-A-1: la tele no queda fija"; return; }
	[ "$(cat $F/force)" = on ] && return
	if [ "$(head -c 8 $HDMI/edid 2>/dev/null | od -An -tx1 | tr -d ' \n')" = 00ffffffffffff00 ] \
		&& [ "$(wc -c < $HDMI/edid)" -ge 128 ]; then
		cmp -s $HDMI/edid $EDID_COPIA || { cat $HDMI/edid > $EDID_COPIA.nuevo && mv $EDID_COPIA.nuevo $EDID_COPIA; }
		origen="leídos de la tele"
	else
		origen="copia guardada"
	fi
	[ -s $EDID_COPIA ] || { log "AVISO: sin datos válidos de la tele: no queda fija"; return; }
	cat $EDID_COPIA > $F/edid_override && echo on > $F/force \
		&& log "tele fija: siempre conectada, datos $origen ($(wc -c < $EDID_COPIA) bytes)" \
		|| log "AVISO: no pude dejar la tele fija"
}

log "vigilante v1.4.1: tele $(cat $HDMI/status), Android en la $(estado)"

cuenta=0; cambios=""
while :; do
	if tele_conectada; then quiero=tele; lim=3; else quiero=notebook; lim=5; fi   # 6 s / 10 s seguidos
	if [ "$quiero" = "$(estado)" ]; then
		cuenta=0
		[ -n "$MIRAR" ] && { log "(solo mirar) todo bien: Android ya está en la $quiero"; exit 0; }
		[ "$quiero" = tele ] && fijar_tele
	else
		cuenta=$((cuenta+1))
		if [ "$cuenta" -ge "$lim" ]; then
			if [ -n "$MIRAR" ]; then log "(solo mirar) pasaría Android a la $quiero"; exit 0; fi
			t=$(date +%s); recientes=""
			for c in $cambios; do [ $((t - c)) -lt 300 ] && recientes="$recientes $c"; done
			set -- $recientes
			if [ "$#" -ge 4 ]; then
				log "FRENO: $# cambios en 5 minutos; dejo la pantalla como está (revisar el cable o la tele)"
				exit 0
			fi
			cambios="$recientes $t"
			cambiar $quiero
			cuenta=0
		fi
	fi
	sleep 2
done
