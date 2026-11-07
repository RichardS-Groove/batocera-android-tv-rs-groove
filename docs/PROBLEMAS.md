# Problemas conocidos y su arreglo

Todo esto pasó en el equipo de prueba (Dell Inspiron 3493). Los registros se leen desde la Batocera:

| Registro | Qué tiene |
| --- | --- |
| `/userdata/android-tv/lanzador.log` | Lo que hizo el lanzador del menú (pantalla elegida, `BootNext`) |
| `/userdata/android-tv/data/bootlog.txt` | El arranque (initrd) |
| `/userdata/android-tv/data/kmsg.txt` | El núcleo (Linux) |
| `/userdata/android-tv/data/log.txt` | Android completo (logcat), al apagarse |
| `/userdata/android-tv/data/rsgroove/arranque.log` | Nuestro `arranque.sh` |

## Pantalla negra después del logo

**Causa:** la tele no estaba detectada y la pantalla de la notebook estaba apagada (`video=eDP-1:d`). En `kmsg.txt`:
`Cannot find any crtc or sizes` → Android sin aceleración → `system_server` reiniciándose en bucle.

**Arreglo:** la pantalla automática del lanzador (tele si el HDMI está conectado, notebook si no). A mano: entradas
«solo la tele» o «solo la pantalla de la notebook» del menú de arranque.

## El asistente se queda en «Searching for accessories…»

Busca un control Bluetooth. **Esc** o **Atrás**, o **Win + F11** y **F10**. O la entrada «Android TV (sin asistente
inicial)» (`SETUPWIZARD=0`).

## El arranque se frena en una consola

`DEBUG=1` abre una consola y espera `exit`. Usá `DEBUG=0` (igual guarda `bootlog.txt`).

## Al reiniciar Android vuelve a Android

El equipo arrancaba de nuevo Android en vez de la Batocera. **Arreglo:** `arranque.sh` pone `BootNext` = la primera
entrada de `BootOrder` (la Batocera). En efivarfs hay que escribir los 6 bytes de una sola vez (`printf` falla); por
eso copia los primeros 6 bytes de `BootOrder`. Mientras tanto: menú de arranque del equipo (Dell: **F12**).

## El Wi-Fi de 5 GHz se conecta y se cae

La red era **solo WPA3**: Android se asociaba y, al recibir la IP, se desconectaba (aviso `TRANSITION-DISABLE` del
router). Con **WPA2** (o mixta WPA2/WPA3) anda en 2,4 y en 5 GHz.

## Google Play Services al 700 % de CPU

Con MindTheGapps, Google Play Services es ARM y corre traducido. **Arreglo:** NotSoGapps (microG). Ver
[GOOGLE.md](GOOGLE.md).

## «Hubo un problema comunicándose con los servidores de Google»

microG viejo (`MissingDroidguard`) o sin registrar. **Arreglo:** microG 0.3.17+ y sus ajustes (check-in, GCM,
SafetyNet, DroidGuard en «Embedded»). Ver [GOOGLE.md](GOOGLE.md).

## La Play Store tarda y no carga todas las carátulas

La Play Store era solo ARM y usaba casi toda la CPU por el traductor. **Arreglo:** Play Store de Android TV con
x86_64, como actualización. Ver [GOOGLE.md](GOOGLE.md).

## El teclado de la notebook escribe mal (ñ, acentos, símbolos)

Android 14 elige el diseño del teclado físico según el idioma del teclado en pantalla y, si no encuentra uno, pone
«Inglés (EE. UU.)». En Android TV no hay pantalla para cambiarlo. Editar a mano `selected-keyboard-layout` en
`input-manager-state.xml` **no sirve**: es un resumen que Android rearma al arrancar. **Arreglo:**
`herramientas/teclado-espanol.sh` (modo clásico + diseño guardado). Ver [INSTALAR.md](INSTALAR.md), paso 11.

## La palanca derecha cambia el volumen dentro de un juego

Es a propósito (como en la Batocera). Si un juego de Android usa la palanca derecha, también cambia el volumen. Para
apagarlo, en `arranque.sh` borrá el bloque `ABS_RZ)`.

## El celular no encuentra el Android TV (app Google TV)

El Android TV Remote Service no tenía permiso de Bluetooth y dejaba el emparejamiento apagado («Pairing server is
down»). **Arreglo:** [CELULAR.md](CELULAR.md).

## No aparecen Chrome ni Drive en la Play Store

Google no los publica para Android TV. **Arreglo:** versiones de celular, [GOOGLE.md](GOOGLE.md).

## El inicio RS Groove no muestra Chrome ni Drive

Muestra solo apps de TV. Las de celular van en `library_apps` del tema o se suman con la Biblioteca de aplicaciones.
Ver [INICIO.md](INICIO.md).

## Los `.bat` de Java o Android fallan con «no se reconoce como un comando»

Si el usuario de Windows tiene `&` en el nombre, los `.bat` se rompen: usá una carpeta como `C:\rsgtv`. Si sigue,
llamá al `.bat` con su ruta completa (Windows puede tener apagada la búsqueda en la carpeta actual).

## Katniss gasta CPU

`adb shell pm disable-user com.google.android.katniss`.

## GRUB toma el pendrive

Con el pendrive de la ISO puesto, el GRUB de Android puede encontrar la marca `/.disk/<…>.uuid` del pendrive. Sacalo.

## Pendientes (todavía sin arreglo)

- **Bluetooth de Android** se cae en el Qualcomm QCA9377 (`LE_ADV_FILTER` en el registro).
- Si la tele se enchufa con Android ya prendido, falta comprobar si Android la toma sola o hay que reiniciar.
- Widevine es **L3** en x86: algunas apps de video van en SD.
