#!/bin/sh
# batocera-android-tv-rs-groove — genera rsgroove/init.sh a partir del init.sh original de Android.
#
# Agrega 2 líneas en el caso «kmsg)» del init.sh de LineageOS-TV-x86 (servicio kmsg_fetch, corre como root
# todo el tiempo) para lanzar /data/rsgroove/arranque.sh en cada arranque. No cambia nada más.
#
# Uso:  sh generar-init.sh <init.sh original> <salida>
# Ej.:  sh generar-init.sh init.sh.original /userdata/android-tv/rsgroove/init.sh
set -eu

ORIG=${1:?Falta el init.sh original}
SAL=${2:?Falta la ruta de salida}
CASO='	kmsg)'

[ -f "$ORIG" ] || { echo "No existe: $ORIG" >&2; exit 1; }
grep -qx "$CASO" "$ORIG" || { echo "No encuentro el caso «kmsg)» en $ORIG: esta versión de Android no es compatible." >&2; exit 1; }
if grep -q '/data/rsgroove/arranque.sh' "$ORIG"; then
	echo "Ese init.sh ya tiene las líneas de RS Groove: usá el original, sin modificar." >&2
	exit 1
fi

TMP="$SAL.tmp.$$"
while IFS= read -r l || [ -n "$l" ]; do
	printf '%s\n' "$l"
	if [ "$l" = "$CASO" ]; then
		printf '%s\n' '		# batocera-android-tv (RichardS-Groove): arranque propio (ADB por red + atajo Select+Start)'
		printf '%s\n' '		[ -f /data/rsgroove/arranque.sh ] && /system/bin/sh /data/rsgroove/arranque.sh &'
	fi
done < "$ORIG" > "$TMP"

mv "$TMP" "$SAL"
chmod 755 "$SAL"
echo "Listo: $SAL"
