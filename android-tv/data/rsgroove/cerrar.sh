#!/system/bin/sh
# Cerrar todo — Android TV RS Groove (v1.0.0, 08/11/2026). Lo lanza arranque.sh en cada arranque (corre como root).
# Pedido de la persona: cerrar todo, también un video flotante que no se podía cerrar ni con el joystick ni con el
# control del celular. Dos formas de pedirlo:
#   1) la app «Cerrar todo» (ar.rsgroove.cerrartodo) en el inicio: se abre con el celular o el joystick; una app común
#      no puede cerrar otras, así que la app solo se abre y este script, al verla, hace el cierre;
#   2) joystick: Select + Círculo juntos.
# Cierra (force-stop) las apps de todas las tareas abiertas, incluida la ventanita flotante, salvo el inicio RS Groove
# y el sistema; después vuelve al inicio. Registro: /data/rsgroove/cerrar.log
D=/data/rsgroove
LOG=$D/cerrar.log
ahora() { date '+%F %T'; }
QUEDAN=" com.gathin.tvhome com.android.systemui android ar.rsgroove.cerrartodo "

cerrar_todo() {  # $1 = quién lo pidió
	lista=$(dumpsys activity activities 2>/dev/null \
		| sed -n 's/.*Task{[^ ]* #[0-9]* type=[a-z]* A=[0-9]*:\([^ ]*\) .*/\1/p' | sort -u)
	cerradas=""
	for p in $lista; do
		case "$QUEDAN" in *" $p "*) continue ;; esac
		am force-stop "$p" && cerradas="$cerradas $p"
	done
	am force-stop ar.rsgroove.cerrartodo
	am start -n com.gathin.tvhome/.MainActivity >/dev/null 2>&1
	echo "$(ahora) cerrar todo ($1):${cerradas:- no había nada abierto}" >> $LOG
}

echo "$(ahora) cerrar.sh v1.0.0 empezó" >> $LOG

# 1) La app «Cerrar todo»: Android anota cada pantalla que se abre (evento wm_on_resume_called).
(logcat -b events -T 1 -v brief 2>/dev/null | while read -r l; do
	case "$l" in *wm_on_resume_called*ar.rsgroove.cerrartodo.Cerrar*) cerrar_todo "app" ;; esac
done) &

# 2) Joystick: Select + Círculo juntos (Círculo = botón 289 = BTN_THUMB en el ShanWan).
sel=0; cir=0
getevent -ql 2>/dev/null | while read -r _d _t code value; do
	case "$code" in
		BTN_SELECT|BTN_BASE3) case "$value" in DOWN) sel=1 ;; UP) sel=0 ;; esac ;;
		BTN_THUMB) case "$value" in DOWN) cir=1 ;; UP) cir=0 ;; esac ;;
		*) continue ;;
	esac
	if [ "$sel" = 1 ] && [ "$cir" = 1 ]; then cerrar_todo "joystick"; sel=0; cir=0; fi
done
