#!/bin/bash
# Gancho oficial de la Batocera: S12populateshare lo corre como «/boot/postshare.sh start» en cada arranque, recién
# montado /userdata y antes del menú, el Wi-Fi y el sonido. Va en la partición de arranque: /boot/postshare.sh
# Android TV RS Groove (v1.5.0): «tele fija» — si la Batocera arrancó con la tele conectada, apagar y prender la tele
# con su control no reinicia el menú ni cambia la pantalla (ver docs/COMO-FUNCIONA.md).
# Si ya tenés un /boot/postshare.sh, NO lo reemplaces: agregá solo las dos líneas de «tele fija» antes de su final.
[ "$1" = "start" ] || exit 0
[ -f /userdata/system/tele-fija/tele-fija.sh ] \
	&& timeout 30 bash /userdata/system/tele-fija/tele-fija.sh >> /userdata/system/logs/tele-fija.log 2>&1
exit 0
