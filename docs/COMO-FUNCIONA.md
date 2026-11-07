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
    A->>A: ADB por red :5555 y atajo Select + Start
    A->>U: Select + Start → reinicio
    U->>B: arranca la Batocera
```

## Las piezas

| Pieza | Dónde vive | Qué hace |
| --- | --- | --- |
| `es_systems_android.cfg` | `/userdata/system/configs/emulationstation/` | Suma el sistema «Android TV» al menú. Lo lee el menú y sobrevive a las actualizaciones. |
| `Android TV.sh` + `gamelist.xml` | `/userdata/roms/android/` | El lanzador: elige la pantalla, arma `BootNext` y reinicia limpio. |
| Entrada UEFI «Android TV» | NVRAM del equipo | Apunta a `\EFI\android\bootx64.efi`. **No está en `BootOrder`**: solo se usa con `BootNext`. |
| `bootx64.efi`, `boot/grub/`, `.disk/<marca>.uuid` | Partición FAT32 aparte | El GRUB de la ISO encuentra su configuración por la marca. |
| `grub.cfg` | Partición FAT32, `boot/grub/` | Menú de arranque: automático, solo tele, solo notebook, sin asistente, video seguro, volver a la Batocera. |
| `pantalla.cfg` | Partición FAT32, `EFI/android/` | Lo escribe el lanzador antes de reiniciar. |
| `kernel`, `initrd.img`, `system.img`, `ramdisk-recovery.img` | `/userdata/android-tv/` | Android. `system.img` es el sistema modificable (ext4). |
| `data/` | `/userdata/android-tv/data/` | El `/data` de Android: apps, cuentas y ajustes. |
| `fstab.android` | `/userdata/android-tv/` | Qué monta el initrd y desde dónde. |
| `scripts/9-rsgroove` | `/userdata/android-tv/scripts/` | El initrd carga `scripts/*` con `source`; este define `post_detect()` y monta nuestro `init.sh`. |
| `rsgroove/init.sh` | `/userdata/android-tv/rsgroove/` | El `init.sh` de Android + 2 líneas que lanzan `arranque.sh`. Lo genera `herramientas/generar-init.sh`. |
| `arranque.sh` | `/userdata/android-tv/data/rsgroove/` (= `/data/rsgroove/`) | Corre como root en cada arranque: `BootNext`, ADB por red, atajo Select + Start. |
| `Vendor_2563_Product_0523.kl` | `/data/system/devices/keylayout/` | Botones como en la Batocera para el joystick ShanWan. |

## Por qué sobrevive a las actualizaciones de la Batocera

- Todo está en `/userdata`, en una partición FAT32 aparte y en una entrada UEFI propia. Nada en la partición
  `BATOCERA`, que es la que la actualización reescribe.
- Ningún script de la Batocera usa `efibootmgr`: las actualizaciones no tocan entradas UEFI ajenas.
- La Batocera sigue primera en `BootOrder`: si algo de Android falla, el equipo arranca la Batocera.

## Por qué un reinicio limpio

Un apagado de golpe dañó una vez `batocera.conf`. El lanzador usa `batocera-es-swissknife --reboot`, que cierra el
menú y los servicios en orden. Se lanza desacoplado (`setsid … &`) porque mata al «emulador» que lo llamó.
