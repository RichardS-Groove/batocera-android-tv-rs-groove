#!/system/bin/sh
# Proyecto batocera-android-tv (RichardS-Groove) — corre como root al arrancar Android (lo lanza init.sh kmsg).
# 1) Prende ADB por red (puerto 5555) para que la PC pueda controlar Android.
# 2) Atajo del joystick: Select + Start juntos -> reinicia -> vuelve la Batocera.
# 3) Palanca derecha, como en la Batocera: arriba sube el volumen, abajo lo baja (sostenida, repite).
# 4) Lanza fondos.sh: fotos nuevas de Unsplash para el inicio.
LOG=/data/rsgroove/arranque.log
echo "$(date '+%F %T') arranque.sh empezó" >> $LOG
# 0) Que cualquier reinicio vuelva a la Batocera: BootNext = primera entrada del orden UEFI.
#    (atributos + primera entrada = los primeros 6 bytes de BootOrder; efivarfs exige una sola escritura)
G=8be4df61-93ca-11d2-aa0d-00e098032b8c; E=/sys/firmware/efi/efivars
if [ -r "$E/BootOrder-$G" ]; then
	head -c 6 "$E/BootOrder-$G" > /data/rsgroove/bootnext.bin
	cat /data/rsgroove/bootnext.bin > "$E/BootNext-$G" 2>>$LOG \
		&& echo "$(date '+%F %T') próximo arranque = $(od -An -tx2 -j4 "$E/BootNext-$G" | tr -d ' ') (Batocera)" >> $LOG
fi
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
setprop service.adb.tcp.port 5555
setprop ctl.restart adbd
echo "$(date '+%F %T') ADB por red en el puerto 5555" >> $LOG
# 4) Fotos nuevas de Unsplash para el inicio (si hay clave en fondos.env); revisa cada hora.
[ -f /data/rsgroove/fondos.sh ] && sh /data/rsgroove/fondos.sh --vigilar >/dev/null 2>&1 &
# Palanca derecha vertical = ABS_RZ (0 arriba … 255 abajo, centro ~128). Fuera de la zona muerta, repite la tecla.
VOL_ARRIBA=60; VOL_ABAJO=195
vol_repetir() { while :; do input keyevent "$1"; sleep 0.05; done; }
sel=0; sta=0; voldir=""; rep=""
getevent -ql 2>/dev/null | while read -r _d _t code value; do
	case "$code" in
		BTN_SELECT|BTN_BASE3) case "$value" in DOWN) sel=1 ;; UP) sel=0 ;; esac ;;
		BTN_START|BTN_BASE4)  case "$value" in DOWN) sta=1 ;; UP) sta=0 ;; esac ;;
		ABS_RZ)
			v=$((16#$value))
			if [ "$v" -lt "$VOL_ARRIBA" ]; then dir=VOLUME_UP
			elif [ "$v" -gt "$VOL_ABAJO" ]; then dir=VOLUME_DOWN
			else dir=""; fi
			if [ "$dir" != "$voldir" ]; then
				[ -n "$rep" ] && kill "$rep" 2>/dev/null
				rep=""; voldir=$dir
				if [ -n "$dir" ]; then vol_repetir "$dir" & rep=$!; fi
			fi
			continue ;;
		*) continue ;;
	esac
	if [ "$sel" = 1 ] && [ "$sta" = 1 ]; then
		echo "$(date '+%F %T') Select+Start: reinicio para volver a la Batocera" >> $LOG
		sync
		svc power reboot 2>/dev/null || reboot
		sleep 30
	fi
done
