# Instalar Android TV en la Batocera

Guía de la versión **1.3.0**. Son los pasos que se hicieron en el equipo de prueba (Dell Inspiron 3493, Batocera 43.1).
Lo que todavía no se probó está marcado **(sin probar)**.

Todos los comandos de la Batocera se escriben por SSH, como `root`.

## Antes de empezar

| Hace falta | Cómo se comprueba |
| --- | --- |
| Batocera x86_64 con arranque UEFI | `ls /sys/firmware/efi` muestra archivos |
| Arranque seguro (Secure Boot) apagado | `mokutil --sb-state` dice `SecureBoot disabled` |
| Unos 12 GB libres en `/userdata` | `df -h /userdata` |
| Una partición **FAT32 que no sea la de la Batocera**, para el cargador de Android | `lsblk -f` (en el equipo de prueba: una partición vieja del segundo disco) |
| SSH a la Batocera desde la PC | `ssh root@<IP-de-la-Batocera>` |

La partición `BATOCERA` (la de arranque de la Batocera) **no se toca nunca**: las actualizaciones la reescriben.

## 1. Bajar la ISO y comprobarla

ISO oficial de la comunidad LineageOS-TV-x86 (SourceForge):
<https://sourceforge.net/projects/lineageos-tv-x86/files/lineage-21.0/x86_64_tv/>

```bash
mkdir -p /userdata/android-tv/descargas && cd /userdata/android-tv/descargas
ISO=lineage-21.0-20260331-UNOFFICIAL-x86_64_tv-signed.iso
curl -L -o "$ISO" "https://sourceforge.net/projects/lineageos-tv-x86/files/lineage-21.0/x86_64_tv/$ISO/download"
sha256sum "$ISO"
# Tiene que dar: 29c44bb7bb0cb6531a11e3778377c985c4c96b881b2666fba3901e4c21d67bc2
```

Si da otra cosa, no sigas: bajala de nuevo.

**Consejo:** antes de instalar, probala en un pendrive (`dd if=$ISO of=/dev/sdX bs=4M` y arrancar con el menú de
arranque del equipo, en Dell **F12**, opción **Try**). Así sabés si imagen, sonido, Wi-Fi y joystick andan en tu equipo.

## 2. Copiar los archivos de Android

```bash
mkdir -p /tmp/iso && mount -o loop,ro "/userdata/android-tv/descargas/$ISO" /tmp/iso
cd /userdata/android-tv
cp /tmp/iso/kernel /tmp/iso/initrd.img /tmp/iso/system.efs /tmp/iso/ramdisk-recovery.img .
mkdir -p data scripts rsgroove
```

El `init` de esta compilación acepta `ROOT=` (la partición), `SRC=` (la carpeta) y usa la carpeta `data/` como
`/data` de Android. Por eso se puede instalar en una carpeta, sin particionar nada.

## 3. Bajar este proyecto a la Batocera

```bash
cd /tmp && curl -L https://github.com/RichardS-Groove/batocera-android-tv-rs-groove/archive/refs/tags/v1.3.0.tar.gz | tar -xz
P=/tmp/batocera-android-tv-rs-groove-1.3.0
```

## 4. El cargador de Android (GRUB) y la entrada UEFI

`V` es la partición FAT32 del cargador, montada por la Batocera en `/media/<NOMBRE>`.

```bash
V=/media/<NOMBRE>
mkdir -p "$V/EFI/android" "$V/boot/grub/fonts" "$V/.disk"
cp -r /tmp/iso/boot/grub/x86_64-efi "$V/boot/grub/"
cp /tmp/iso/boot/grub/fonts/unicode.pf2 "$V/boot/grub/fonts/"
MK=$(ls /tmp/iso/.disk | grep '\.uuid$')          # en la 20260331: 2026-03-15-03-27-47-00.uuid
cp "/tmp/iso/.disk/$MK" "$V/.disk/$MK"
cp "$P/efi/boot/grub/grub.cfg" "$V/boot/grub/grub.cfg"
```

**`bootx64.efi`** es el GRUB de la ISO. Busca el archivo marca `/.disk/<…>.uuid` en todos los discos y usa
`boot/grub/` de esa partición. Está dentro de la partición EFI de la ISO (la 2.ª partición de la imagen híbrida). En
el equipo de prueba se copió del pendrive grabado en el paso 1:

```bash
mkdir -p /tmp/usbefi && mount -o ro /dev/sdX2 /tmp/usbefi
cp /tmp/usbefi/efi/boot/bootx64.efi "$V/EFI/android/bootx64.efi"
umount /tmp/usbefi
```

**Sacá el pendrive después:** con el pendrive puesto, GRUB puede tomar la marca del pendrive en vez de la tuya.

Entrada UEFI propia, **fuera del orden de arranque** (`-C` la crea sin agregarla al orden):

```bash
efibootmgr -C -d /dev/sdX -p N -L "Android TV" -l '\EFI\android\bootx64.efi'
efibootmgr        # «Android TV» aparece y BootOrder sigue igual que antes
```

`-d /dev/sdX -p N` = el disco y el número de la partición FAT32 (en el equipo de prueba, `-d /dev/sda -p 1`).

Antes de crear la entrada conviene guardar cómo estaba todo: `efibootmgr -v > /userdata/android-tv/respaldo-efibootmgr.txt`.

### La hora

El `grub.cfg` trae `SET_TZ_LOCATION=America/Argentina/Buenos_Aires` en la línea `set BASE=…`. Cambialo por tu zona
(por ejemplo `Europe/Madrid`, `America/Mexico_City`).

## 5. La entrada del menú de la Batocera

```bash
mkdir -p /userdata/roms/android
cp "$P/batocera/roms/android/Android TV.sh" "$P/batocera/roms/android/gamelist.xml" /userdata/roms/android/
chmod 755 "/userdata/roms/android/Android TV.sh"
cp "$P/batocera/system/configs/emulationstation/es_systems_android.cfg" /userdata/system/configs/emulationstation/
```

Reiniciá el menú (Menú → Salir → Reiniciar EmulationStation) o la Batocera. Aparece el sistema **Android TV**.

El lanzador:

1. busca la entrada UEFI «Android TV» y comprueba que estén `kernel` y `system.img` o `system.efs`;
2. si la tele está conectada por HDMI, escribe en `EFI/android/pantalla.cfg` que salga solo por la tele; si no, por
   la notebook;
3. arma `BootNext` (un arranque de una sola vez) y reinicia limpio con `batocera-es-swissknife --reboot`.

Deja un registro en `/userdata/android-tv/lanzador.log`.

## 6. Primer arranque de Android

1. Menú de la Batocera → **Android TV**.
2. Si el asistente se queda en **«Searching for accessories…»** (busca un control Bluetooth): **Esc** o **Atrás**, o
   **Win + F11** y **F10**. También está la entrada «Android TV (sin asistente inicial)» del menú de arranque.
3. Conectá el Wi-Fi. Las redes **solo WPA3** se caen: usá WPA2 (o WPA2/WPA3 mixta). Ver
   [PROBLEMAS.md](PROBLEMAS.md).
4. Prendé las opciones para desarrolladores: Configuración → Preferencias del dispositivo → Información → tocá
   **Compilación** 7 veces.
5. En Opciones para desarrolladores: **Depuración por USB**, **Depuración como superusuario** y **ADB sobre red**.
6. Desde la PC: `adb connect <IP-de-Android>:5555` y en la tele aceptá «Permitir siempre desde esta computadora».
   Después `adb root` y `adb connect` de nuevo.

Para volver a la Batocera en este punto: reiniciá. Si el equipo vuelve a Android (pasaba en el equipo de prueba antes
de `arranque.sh`), elegí la Batocera en el menú de arranque del equipo (Dell: **F12**).

## 7. Sistema modificable (`system.img`)

`system.efs` es un contenedor de solo lectura (EROFS) con un `system.img` (ext4) adentro. Para sumar Google y cambios
propios hace falta el `system.img` suelto. Con Android prendido:

```bash
adb shell 'cat /proc/mounts | grep " / "'        # muestra el loop del sistema (en el equipo de prueba: /dev/block/loop1, ext4)
adb shell 'dd if=/dev/block/loop1 of=/data/system.img bs=4M'
```

Reiniciá a la Batocera y, ahí:

```bash
cd /userdata/android-tv
mv data/system.img system.img
mv system.efs system.efs.original               # copia del original, por si hay que volver
cp fstab.android fstab.android.antes-system-img
cp "$P/android-tv/fstab.android" fstab.android   # usa $FS/system$SLOT.img
```

Para volver atrás: `mv system.efs.original system.efs` y `cp fstab.android.antes-system-img fstab.android`. El
lanzador acepta los dos.

## 8. Arranque propio: vuelta a la Batocera, ADB y atajo

```bash
# init.sh original, desde el system.img (ext4)
mkdir -p /tmp/sys && mount -o loop,ro /userdata/android-tv/system.img /tmp/sys
cp /tmp/sys/system/etc/init.sh /tmp/init.sh.original && umount /tmp/sys

# nuestro init.sh = el original + 2 líneas
sh "$P/herramientas/generar-init.sh" /tmp/init.sh.original /userdata/android-tv/rsgroove/init.sh

# script que lo monta al arrancar
cp "$P/android-tv/scripts/9-rsgroove" /userdata/android-tv/scripts/

# lo que corre en cada arranque de Android
mkdir -p /userdata/android-tv/data/rsgroove
cp "$P/android-tv/data/rsgroove/arranque.sh" /userdata/android-tv/data/rsgroove/
chmod 755 /userdata/android-tv/data/rsgroove/arranque.sh
```

La copia del `init.sh` original desde el `system.img` montado en la Batocera está **(sin probar)**: en el equipo de
prueba se sacó con `adb pull /system/etc/init.sh` antes de montar el nuestro. `generar-init.sh` sí está probado: da un
archivo idéntico, byte por byte, al que funciona.

`arranque.sh`, en cada arranque de Android:

1. pone `BootNext` = la primera entrada del orden UEFI (la Batocera), así cualquier reinicio vuelve a la Batocera;
2. espera a que Android termine de arrancar y prende ADB por red en el puerto `5555`;
3. escucha el joystick: **Select + Start** juntos → reinicia → vuelve la Batocera;
4. **palanca derecha** arriba o abajo → sube o baja el volumen (sostenida, repite unas 4 a 5 veces por segundo).

Registro: `/userdata/android-tv/data/rsgroove/arranque.log`.

## 9. Botones como en la Batocera

```bash
K=/userdata/android-tv/data/system/devices/keylayout
mkdir -p "$K"
cp "$P/android-tv/data/system/devices/keylayout/Vendor_2563_Product_0523.kl" "$K/"
chown -R 1000:1000 /userdata/android-tv/data/system/devices
chmod 644 "$K/Vendor_2563_Product_0523.kl"
```

En el equipo de prueba se copió con `adb push` y `adb root`, con Android prendido. Toma efecto al volver a conectar el
joystick o al reiniciar.

## 10. Idioma y hora (opcional)

```bash
adb shell 'setprop persist.sys.locale es-AR; settings put system time_12_24 24; settings put global auto_time_zone 0'
```

La zona horaria ya la fija el `grub.cfg` (paso 4).

## 11. Teclado de la notebook en español

Android 14 pone «Inglés (EE. UU.)» al teclado de la notebook y en Android TV no hay pantalla para cambiarlo. Con
Android prendido:

```bash
adb root
adb push herramientas/teclado-espanol.sh /data/local/tmp/   # desde la carpeta del proyecto, en la PC
adb shell sh /data/local/tmp/teclado-espanol.sh                           # Español (Latinoamérica)
# adb shell sh /data/local/tmp/teclado-espanol.sh keyboard_layout_spanish  # Español (España)
```

Pasa Android al modo clásico (`settings_new_keyboard_ui=false`), donde el diseño queda guardado, y reinicia la
interfaz (unos 30 s). Guarda una copia de la configuración anterior en `/data/rsgroove/`. Se nota en la ñ, los
acentos y la `@` (AltGr + Q en Latinoamérica).

## 12. Google Play, Chrome y Drive

Ver [GOOGLE.md](GOOGLE.md).

## 13. El inicio RS Groove

Ver [INICIO.md](INICIO.md).

## 14. El celular como control remoto

Ver [CELULAR.md](CELULAR.md).

## Adaptar a otro equipo

| Qué cambia | Dónde | Cómo saberlo |
| --- | --- | --- |
| Nombres de las pantallas (`eDP-1`, `HDMI-A-1`) | `Android TV.sh` (lee `card*-HDMI-A-1`) y `grub.cfg` (`SOLO_TELE`, `SOLO_NOTEBOOK`) | En la Batocera: `ls /sys/class/drm/` |
| Resolución de la tele (`1920x1080@60`) | Mismos archivos | La que acepte tu salida HDMI |
| Joystick | Nombre del `.kl`: `Vendor_<VVVV>_Product_<PPPP>.kl`; códigos `288`…`299` | En Android: `cat /proc/bus/input/devices` y `getevent -l` |
| Atajo Select + Start | `arranque.sh` (`BTN_SELECT` o `BTN_BASE3`, `BTN_START` o `BTN_BASE4`) | `getevent -ql` al apretar los botones |
| Partición del cargador | `efibootmgr -d … -p …` | `lsblk -f` |
| Zona horaria | `grub.cfg` (`SET_TZ_LOCATION`) | |

## Desinstalar (sin probar)

```bash
efibootmgr                                  # anotá el número de «Android TV», por ejemplo 0005
efibootmgr -b 0005 -B                       # borra solo esa entrada
rm "/userdata/roms/android/Android TV.sh" /userdata/roms/android/gamelist.xml
rmdir /userdata/roms/android
rm /userdata/system/configs/emulationstation/es_systems_android.cfg
# En la partición FAT32: EFI/android, boot/grub y .disk/<marca>.uuid
# /userdata/android-tv tiene Android y TODAS sus apps y datos: copialo antes si querés guardarlo.
```
