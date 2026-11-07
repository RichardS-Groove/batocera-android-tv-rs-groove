#!/bin/bash
# Reinicia la notebook en Android TV — proyecto batocera-android-tv (RichardS-Groove).
# Elige la pantalla como la Batocera: tele por HDMI si está conectada; si no, la pantalla de la notebook.
# Arma un arranque de una sola vez (BootNext) y reinicia limpio; al reiniciar Android vuelve la Batocera.
LOG=/userdata/android-tv/lanzador.log
ahora() { date "+%F %T"; }
ENT=$(efibootmgr | sed -n "s/^Boot\([0-9A-Fa-f]\{4\}\)\* Android TV.*/\1/p" | head -1)
[ -n "$ENT" ] || { echo "$(ahora) falta la entrada UEFI «Android TV»" >> "$LOG"; exit 1; }
[ -f /userdata/android-tv/kernel ] && { [ -f /userdata/android-tv/system.img ] || [ -f /userdata/android-tv/system.efs ]; } || { echo "$(ahora) faltan archivos de Android" >> "$LOG"; exit 1; }
V=""; for m in /media/*; do [ -f "$m/EFI/android/bootx64.efi" ] && { V="$m"; break; }; done
[ -n "$V" ] || { echo "$(ahora) no encuentro la partición del cargador (EFI/android)" >> "$LOG"; exit 1; }
if grep -qs "^connected" /sys/class/drm/card*-HDMI-A-1/status; then
	MODO="tele"; P="video=eDP-1:d video=HDMI-A-1:1920x1080@60e"
else
	MODO="notebook"; P=""
fi
printf 'set PANTALLA="%s"\n' "$P" > "$V/EFI/android/pantalla.cfg"
efibootmgr -n "$ENT" >/dev/null && echo "$(ahora) pantalla=$MODO, BootNext=$ENT, reinicio limpio" >> "$LOG"
sync
setsid sh -c "sleep 3; batocera-es-swissknife --reboot" >/dev/null 2>&1 < /dev/null &
exit 0
