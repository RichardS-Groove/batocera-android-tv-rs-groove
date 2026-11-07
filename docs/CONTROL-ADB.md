# Controlar Android desde la PC (ADB)

Con Android prendido la Batocera está apagada, así que la PC habla directo con Android por la red.

## Qué queda listo en cada arranque

`arranque.sh` prende ADB por red en el puerto **5555** apenas Android termina de arrancar. La compilación tiene
`ro.adb.secure=1`: **solo entra una PC autorizada** (su llave en `/data/misc/adb/adb_keys`).

## Autorizar la PC (una vez)

Opción A, en la tele: `adb connect <IP-de-Android>:5555` y aceptar «Permitir siempre desde esta computadora».

Opción B, desde la Batocera, antes de arrancar Android (la llave pública de la PC está en `~/.android/adbkey.pub`):

```bash
mkdir -p /userdata/android-tv/data/misc/adb
cat adbkey.pub >> /userdata/android-tv/data/misc/adb/adb_keys
chown 1000:2000 /userdata/android-tv/data/misc/adb/adb_keys
chmod 640 /userdata/android-tv/data/misc/adb/adb_keys
```

Para comandos como root: activar «Depuración como superusuario» en Opciones para desarrolladores y `adb root`.

## Lo de todos los días

```bash
adb connect <IP-de-Android>:5555
adb shell screencap -p /sdcard/foto.png && adb pull /sdcard/foto.png   # foto de la pantalla
adb shell input keyevent DPAD_DOWN                                     # flechas: DPAD_UP/DOWN/LEFT/RIGHT, DPAD_CENTER, BACK, HOME
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml   # textos y botones de la pantalla
adb install -r app.apk
adb logcat -d | tail -100
```

Para verla y manejarla con el mouse: [scrcpy](https://github.com/Genymobile/scrcpy).

## Trampas

- **Git Bash (Windows)** cambia rutas como `/sdcard/x` por rutas de Windows: anteponé `MSYS_NO_PATHCONV=1`.
- **PowerShell**: no redirijas binarios con `>` (rompe los PNG); usá `adb pull`.
- Después de `adb root`, ADB se reinicia: volvé a hacer `adb connect`.

## Apagar el ADB por red

Si no lo querés, borrá en `arranque.sh` las líneas `setprop service.adb.tcp.port 5555` y `setprop ctl.restart adbd`.
