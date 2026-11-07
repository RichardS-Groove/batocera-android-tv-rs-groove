#!/system/bin/sh
# batocera-android-tv-rs-groove — teclado de la notebook en español (Android 14).
#
# Android 14 elige el diseño del teclado físico según el idioma del teclado en pantalla y, si no encuentra uno,
# pone «Inglés (EE. UU.)». Esto pasa al modo clásico (settings_new_keyboard_ui=false), donde el diseño elegido
# queda guardado, y elige el diseño para el teclado de la notebook (AT, vendor 1 / product 1).
#
# Uso, con Android prendido y ADB como root:
#   adb push teclado-espanol.sh /data/local/tmp/ && adb shell sh /data/local/tmp/teclado-espanol.sh [diseño]
# Diseño por defecto: keyboard_layout_spanish_latin (Latinoamérica). España: keyboard_layout_spanish.
# Reinicia la interfaz de Android (unos 30 s de pantalla negra). Las elecciones de otros teclados se borran.
set -e
DIS=${1:-keyboard_layout_spanish_latin}
F=/data/system/input-manager-state.xml
COPIAS=/data/rsgroove

[ "$(id -u)" = 0 ] || { echo "Hace falta root: adb root" >&2; exit 1; }
APK=$(pm path com.android.inputdevices | sed 's/^package://')
unzip -l "$APK" | grep -q "res/raw/$DIS.kcm" || { echo "Android no tiene el diseño $DIS" >&2; exit 1; }

mkdir -p "$COPIAS"
[ -f "$F" ] && cp -p "$F" "$COPIAS/input-manager-state.xml.antes-$(date +%Y%m%d-%H%M%S)"

settings put global settings_new_keyboard_ui false

T=/data/local/tmp/teclado.$$
cat > "$T.xml" <<EOF
<?xml version="1.0" encoding="utf-8" standalone="yes" ?>
<input-manager-state>
  <key-remapping />
  <input-devices>
    <input-device descriptor="vendor:1,product:1">
      <keyboard-layout descriptor="com.android.inputdevices/com.android.inputdevices.InputDeviceReceiver/$DIS" current="true" />
    </input-device>
  </input-devices>
</input-manager-state>
EOF
xml2abx "$T.xml" "$T.abx"
cat "$T.abx" > "$F"
chown system:system "$F"
chmod 600 "$F"
restorecon "$F" 2>/dev/null || true
rm -f "$T.xml" "$T.abx"

echo "Listo: $DIS. Reiniciando la interfaz de Android (unos 30 s)…"
setprop ctl.restart zygote
