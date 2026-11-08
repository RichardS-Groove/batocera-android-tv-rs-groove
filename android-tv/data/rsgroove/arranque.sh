#!/system/bin/sh
# Proyecto batocera-android-tv (RichardS-Groove) — corre como root al arrancar Android (lo lanza init.sh kmsg).
# 0) Que cualquier reinicio vuelva a la Batocera (BootNext).
# 1) Prende ADB por red (puerto 5555) para que la PC pueda controlar Android.
# 2) Atajo del joystick: Select + Start juntos -> reinicia -> vuelve la Batocera.
# 3) Palanca derecha, como en la Batocera: arriba sube el volumen, abajo lo baja (sostenida, repite).
# 4) Lanza fondos.sh: fotos nuevas para el inicio.
# 5) Revisión de arranque (v1.4.0, 07/11/2026): dice si la sesión anterior se cerró bien, carga los ajustes
#    necesarios (ajustes.conf), revisa que los archivos importantes estén sanos y repone los que falten,
#    deja el Wi-Fi sin ahorro de energía y marca cada cierre ordenado. Resumen en revision.log.
# 6) Pantalla automática (v1.4.0): lanza pantalla.sh — tele si está conectada, si no la notebook.
# 7) Cerrar todo (v1.4.0): lanza cerrar.sh — la app «Cerrar todo» o Select + Círculo cierran todas las apps.
D=/data/rsgroove
LOG=$D/arranque.log
REV=$D/revision.log
RESP=$D/respaldo
ahora() { date '+%F %T'; }
echo "$(ahora) arranque.sh empezó" >> $LOG
# 0) Que cualquier reinicio vuelva a la Batocera: BootNext = primera entrada del orden UEFI.
#    (atributos + primera entrada = los primeros 6 bytes de BootOrder; efivarfs exige una sola escritura)
G=8be4df61-93ca-11d2-aa0d-00e098032b8c; E=/sys/firmware/efi/efivars
if [ -r "$E/BootOrder-$G" ]; then
	head -c 6 "$E/BootOrder-$G" > $D/bootnext.bin
	cat $D/bootnext.bin > "$E/BootNext-$G" 2>>$LOG \
		&& echo "$(ahora) próximo arranque = $(od -An -tx2 -j4 "$E/BootNext-$G" | tr -d ' ') (Batocera)" >> $LOG
fi
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
setprop service.adb.tcp.port 5555
setprop ctl.restart adbd
echo "$(ahora) ADB por red en el puerto 5555" >> $LOG

# 5) Revisión de arranque ------------------------------------------------------------------------------
revisar() {
	avisos=0
	# ¿Cómo terminó la sesión anterior de Android? (boot_id distingue un relanzamiento de un arranque nuevo)
	bid=$(cat /proc/sys/kernel/random/boot_id)
	if [ -f $D/cierre-ordenado ]; then
		echo "$(ahora) sesión anterior: cerrada bien ($(cat $D/cierre-ordenado))" >> $REV
		rm -f $D/cierre-ordenado
	elif [ -f $D/sesion-abierta ]; then
		if grep -q "$bid" $D/sesion-abierta; then
			echo "$(ahora) revisión relanzada en la misma sesión" >> $REV
		else
			echo "$(ahora) AVISO sesión anterior: terminó de golpe (corte de luz o apagado con el botón)" >> $REV
			avisos=$((avisos+1))
		fi
	fi
	echo "$(ahora) $bid" > $D/sesion-abierta
	# Archivos importantes: si falta uno o quedó vacío, se repone desde la copia; si está sano, se actualiza la copia.
	mkdir -p $RESP
	for f in /data/system/devices/keylayout/Vendor_2563_Product_0523.kl /data/misc/adb/adb_keys \
	         $D/fondos.env $D/fondos.sh; do
		c=$RESP/$(basename "$f")
		if [ -s "$f" ]; then
			cmp -s "$f" "$c" 2>/dev/null || cp -p "$f" "$c"
		elif [ -s "$c" ]; then
			mkdir -p "$(dirname "$f")"; cp -p "$c" "$f"
			echo "$(ahora) REPUESTO $f (faltaba o estaba vacío)" >> $REV; avisos=$((avisos+1))
		else
			echo "$(ahora) AVISO falta $f y no hay copia" >> $REV; avisos=$((avisos+1))
		fi
	done
	for f in /data/system/users/0/settings_global.xml /data/system/users/0/settings_secure.xml \
	         /data/system/users/0/settings_system.xml /data/system/packages.xml; do
		[ -s "$f" ] || { echo "$(ahora) AVISO $f vacío o ausente" >> $REV; avisos=$((avisos+1)); }
	done
	# Ajustes necesarios (ajustes.conf: «espacio clave valor»; espacio = global, secure, system o prop).
	# Solo se cambia lo que no coincide. «prop» = propiedad del sistema que se pierde al reiniciar.
	n=0
	if [ -f $D/ajustes.conf ]; then
		while read -r ns key val; do
			case "$ns" in
				global|secure|system) cur=$(settings get "$ns" "$key" 2>/dev/null) ;;
				prop) cur=$(getprop "$key") ;;
				file)	# archivo del sistema (acepta comodines, p. ej. todos los núcleos del procesador)
					k=0
					for p in $key; do
						[ -w "$p" ] || continue
						[ "$(cat "$p")" = "$val" ] && continue
						echo "$val" > "$p" && k=$((k+1))
					done
					[ "$k" -gt 0 ] && echo "$(ahora) ajuste file $key -> «$val» ($k)" >> $REV
					n=$((n+k)); continue ;;
				*) continue ;;
			esac
			if [ "$cur" != "$val" ]; then
				if [ "$ns" = prop ]; then setprop "$key" "$val"; else settings put "$ns" "$key" "$val"; fi
				echo "$(ahora) ajuste $ns/$key: «$cur» -> «$val»" >> $REV; n=$((n+1))
			fi
		done < $D/ajustes.conf
	fi
	# Inicio RS Groove como pantalla de inicio.
	home=$(cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN 2>/dev/null | tail -1)
	if [ -n "$home" ] && [ "$home" != "com.gathin.tvhome/.MainActivity" ] && pm path com.gathin.tvhome >/dev/null 2>&1; then
		cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity >/dev/null 2>&1
		# Si en pantalla quedó la pregunta «elegir pantalla de inicio», se cierra sola abriendo el inicio RS Groove.
		am start -n com.gathin.tvhome/.MainActivity >/dev/null 2>&1
		echo "$(ahora) inicio: «$home» -> inicio RS Groove" >> $REV; n=$((n+1))
	fi
	echo "$(ahora) revisión: $n ajustes corregidos, $avisos avisos" >> $REV
}
revisar

# Wi-Fi sin ahorro de energía (control del celular y videos sin cortes). Se repite porque al reconectar vuelve.
(while :; do
	iw dev wlan0 get power_save 2>/dev/null | grep -q ": on" && iw dev wlan0 set power_save off \
		&& echo "$(ahora) Wi-Fi: ahorro de energía apagado" >> $REV
	sleep 30
done) &
# Marca de cierre ordenado: cualquier apagado o reinicio pedido (menú, Select + Start) la deja antes de cerrar.
(until [ -n "$(getprop sys.shutdown.requested)" ]; do sleep 1; done
	echo "$(ahora) ($(getprop sys.shutdown.requested))" > $D/cierre-ordenado
	rm -f $D/sesion-abierta; sync) &

# 4) Fotos nuevas para el inicio (si hay clave en fondos.env); revisa cada hora.
[ -f $D/fondos.sh ] && sh $D/fondos.sh --vigilar >/dev/null 2>&1 &
# 6) Pantalla automática (pantalla.sh, 07/11/2026): tele si está conectada, si no la notebook; vigila
#    enchufar y desenchufar, como la Batocera. Registro en pantalla.log.
[ -f $D/pantalla.sh ] && sh $D/pantalla.sh >/dev/null 2>&1 &
# 7) Cerrar todo (cerrar.sh, 08/11/2026): la app «Cerrar todo» o Select + Círculo cierran todas las apps abiertas,
#    también la ventanita flotante. Registro en cerrar.log.
[ -f $D/cerrar.sh ] && sh $D/cerrar.sh >/dev/null 2>&1 &
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
		echo "$(ahora) Select+Start: reinicio para volver a la Batocera" >> $LOG
		sync
		svc power reboot 2>/dev/null || reboot
		sleep 30
	fi
done
