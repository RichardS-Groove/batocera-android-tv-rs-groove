#!/system/bin/sh
# Pantalla automática — Android TV RS Groove (v1.3.1, 07/11/2026). La lanza arranque.sh en cada arranque.
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
# Uso: pantalla.sh            vigila (lo normal)
#      pantalla.sh --mirar    solo dice qué haría, sin cambiar nada
# Registro: /data/rsgroove/pantalla.log
D=/data/rsgroove
LOG=$D/pantalla.log
MIRAR=""; [ "$1" = "--mirar" ] && MIRAR=1
ahora() { date '+%F %T'; }
log() { echo "$(ahora) $*" >> $LOG; [ -n "$MIRAR" ] && echo "$*"; }

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

log "vigilante v1.3.1: tele $(cat $HDMI/status), Android en la $(estado)"

cuenta=0; cambios=""
while :; do
	if tele_conectada; then quiero=tele; lim=3; else quiero=notebook; lim=5; fi   # 6 s / 10 s seguidos
	if [ "$quiero" = "$(estado)" ]; then
		cuenta=0
		[ -n "$MIRAR" ] && { log "(solo mirar) todo bien: Android ya está en la $quiero"; exit 0; }
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
