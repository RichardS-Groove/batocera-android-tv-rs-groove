# Cómo funciona

## El camino completo

```mermaid
sequenceDiagram
    participant B as Batocera (menú)
    participant L as Android TV.sh
    participant U as Firmware UEFI
    participant G as GRUB de Android
    participant I as initrd de Android
    participant A as Android TV
    B->>L: el usuario elige «Android TV»
    L->>L: ¿HDMI conectado? → escribe EFI/android/pantalla.cfg
    L->>U: efibootmgr -n (BootNext = «Android TV»)
    L->>B: batocera-es-swissknife --reboot (reinicio limpio)
    U->>G: arranca EFI/android/bootx64.efi una sola vez
    G->>I: kernel + initrd.img con ROOT=LABEL=SHARE SRC=/android-tv + pantalla
    I->>I: 9-rsgroove: monta rsgroove/init.sh sobre /system/etc/init.sh
    I->>A: arranca Android (system.img + carpeta data/)
    A->>U: arranque.sh: BootNext = Batocera
    A->>A: ADB por red :5555, atajo Select + Start y volumen con la palanca derecha
    A->>U: Select + Start → reinicio
    U->>B: arranca la Batocera
```

## Las piezas

| Pieza | Dónde vive | Qué hace |
| --- | --- | --- |
| `es_systems_android.cfg` | `/userdata/system/configs/emulationstation/` | Suma el sistema «Android TV» al menú. Lo lee el menú y sobrevive a las actualizaciones. |
| `Android TV.sh` + `gamelist.xml` | `/userdata/roms/android/` | El lanzador: arma `BootNext` y reinicia limpio. Desde la v1.4.0 deja `pantalla.cfg` vacío: Android arranca siempre en la notebook y `pantalla.sh` lo pasa a la tele. |
| Entrada UEFI «Android TV» | NVRAM del equipo | Apunta a `\EFI\android\bootx64.efi`. **No está en `BootOrder`**: solo se usa con `BootNext`. |
| `bootx64.efi`, `boot/grub/`, `.disk/<marca>.uuid` | Partición FAT32 aparte | El GRUB de la ISO encuentra su configuración por la marca. |
| `grub.cfg` | Partición FAT32, `boot/grub/` | Menú de arranque: automático, solo tele, solo notebook, sin asistente, video seguro, volver a la Batocera. |
| `pantalla.cfg` | Partición FAT32, `EFI/android/` | Lo escribe el lanzador antes de reiniciar. |
| `kernel`, `initrd.img`, `system.img`, `ramdisk-recovery.img` | `/userdata/android-tv/` | Android. `system.img` es el sistema modificable (ext4). |
| `data/` | `/userdata/android-tv/data/` | El `/data` de Android: apps, cuentas y ajustes. |
| `fstab.android` | `/userdata/android-tv/` | Qué monta el initrd y desde dónde. |
| `scripts/9-rsgroove` | `/userdata/android-tv/scripts/` | El initrd carga `scripts/*` con `source`; este define `post_detect()` y monta nuestro `init.sh`. |
| `rsgroove/init.sh` | `/userdata/android-tv/rsgroove/` | El `init.sh` de Android + 2 líneas que lanzan `arranque.sh`. Lo genera `herramientas/generar-init.sh`. |
| `arranque.sh` | `/userdata/android-tv/data/rsgroove/` (= `/data/rsgroove/`) | Corre como root en cada arranque: `BootNext`, ADB por red, atajo Select + Start y volumen con la palanca derecha (`ABS_RZ` → `input keyevent VOLUME_UP/DOWN`). |
| `pantalla.sh` | `/data/rsgroove/` | Pantalla automática: con la tele conectada pasa Android a la tele y el sonido al HDMI; sin tele, vuelve a la notebook. |
| `cerrar.sh` + app `ar.rsgroove.cerrartodo` | `/data/rsgroove/` y el inicio | «Cerrar todo»: cierra todas las apps abiertas (también la ventanita flotante) y vuelve al inicio. |
| `ajustes.conf` | `/data/rsgroove/` | Ajustes que la revisión de arranque repone en cada arranque (idioma, animaciones, video por la placa, procesador, memoria). |
| `Vendor_2563_Product_0523.kl` | `/data/system/devices/keylayout/` | Botones como en la Batocera para el joystick ShanWan. |

## La pantalla: notebook o tele (v1.4.0)

- Android arranca **siempre en la pantalla de la notebook**, sin órdenes `video=` al cargador. Con
  `video=eDP-1:d video=HDMI-A-1:…` (o apagando la notebook antes de prender la imagen) la tele quedaba **azul y rayada**.
- `pantalla.sh` mira cada 2 s `/sys/class/drm/card*-HDMI-A-1/status`. Si la tele está conectada 6 s seguidos:
  1. sonido por la tele (ver abajo); 2. `echo off > card*-eDP-1/status` y `setprop ctl.restart vendor.hwcomposer-2-4`
  (la imagen se va a negro unos 30 s y vuelve en la tele); 3. comprueba otra vez el sonido.
  Si la tele se desconecta 10 s, hace lo mismo al revés. Freno: 4 cambios en 5 minutos.
- Registro: `/data/rsgroove/pantalla.log`.

## Apagar la tele para dormir: «tele fija» (v1.5.0)

Muchas teles, al prenderse, avisan por el HDMI que se desconectaron y volvieron (~1 s). Sin arreglo:

- **Android** vuelve a leer los datos de la tele (EDID) mientras la tele todavía está despertando, los lee mal
  («Display identification data has unknown format»), cambia a **1024×768** y la parte de ventanas se traba hasta que
  su vigilante (`Watchdog`) la reinicia.
- **La Batocera** reinicia el menú: la regla udev `80-switch-screen.rules` → `batocera-switch-screen-checker` →
  `curl http://localhost:1234/quit`.

Con la tele fija, el núcleo toma la tele como **siempre conectada** y con **sus datos guardados**, por
`debugfs` (`/sys/kernel/debug/dri/*/HDMI-A-1/`):

```sh
cat <datos-de-la-tele.bin> > /sys/kernel/debug/dri/*/HDMI-A-1/edid_override   # EDID fijo
echo on > /sys/kernel/debug/dri/*/HDMI-A-1/force                               # siempre conectada
```

- **Android:** `pantalla.sh` lo hace en cuanto Android está en la tele. Usa los datos que da la tele en ese momento si
  son válidos (cabecera `00 FF FF FF FF FF FF 00`) y los guarda en `/data/rsgroove/tele-samsung-edid.bin`; si no, usa
  esa copia. Registro: «tele fija: …» en `pantalla.log`.
- **Batocera:** `/userdata/system/tele-fija/tele-fija.sh`, llamado desde `/boot/postshare.sh` en cada arranque, hace lo
  mismo **solo si arrancó con la tele conectada**. Además tapa `batocera-switch-screen-checker-delayed` con
  `aviso-pantalla.sh` (`mount --bind`, se pierde al reiniciar): mientras la tele está fija, el aviso solo vuelve a poner
  el volumen y anota «Tele fija: aviso de pantalla ignorado» en `display.log`. Registro: `logs/tele-fija.log`.
- **Lo que se pierde:** si desenchufás el cable con el equipo prendido, la pantalla de la notebook vuelve recién al
  reiniciar. Al arrancar, la pantalla se sigue eligiendo sola.
- **Volver atrás:** sacar la llamada de `/boot/postshare.sh` (o la carpeta `tele-fija`) y reiniciar; en Android, la
  versión 1.3.1 de `pantalla.sh`.

Además, **Android nunca se duerme** (`ajustes.conf`: `secure sleep_timeout -1` y `secure attentive_timeout -1`) y con
`stay_on_while_plugged_in 1` la pantalla no se apaga (solo baja el brillo a los 15 minutos, cosa que la tele no
muestra). Esta compilación tampoco suspende el equipo: `write /sys/power/state` falla.

## Sonido por la tele

El controlador de sonido principal (`audio.primary.x86`) **ignora las salidas HDMI** («ignore pcmC0D3p») salvo con
`hal.audio.primary.hdmi=1`. Sin esa opción Android queda sin ninguna salida y las apps dicen «tu formato de video no es
compatible». `pantalla.sh` pone `hal.audio.primary.hdmi=1` y `hal.audio.out` / `hal.audio.out.speaker` = `pcmC0D3p`
(HDMI 0), y reinicia en orden el controlador (`vendor.audio-hal`), espera, y después `audioserver`.

## Cerrar todo

Una app común no puede cerrar otras. La app «Cerrar todo» solo se abre; `cerrar.sh` (root) la ve en el registro de
eventos (`wm_on_resume_called`) y hace `am force-stop` a las apps de todas las tareas abiertas, salvo el inicio y el
sistema, y vuelve al inicio. Lo mismo con **Select + Círculo**. Registro: `/data/rsgroove/cerrar.log`.

## Por qué sobrevive a las actualizaciones de la Batocera

- Todo está en `/userdata`, en una partición FAT32 aparte y en una entrada UEFI propia. Nada en la partición
  `BATOCERA`, que es la que la actualización reescribe.
- Ningún script de la Batocera usa `efibootmgr`: las actualizaciones no tocan entradas UEFI ajenas.
- La Batocera sigue primera en `BootOrder`: si algo de Android falla, el equipo arranca la Batocera.

## Por qué un reinicio limpio

Un apagado de golpe dañó una vez `batocera.conf`. El lanzador usa `batocera-es-swissknife --reboot`, que cierra el
menú y los servicios en orden. Se lanza desacoplado (`setsid … &`) porque mata al «emulador» que lo llamó.
