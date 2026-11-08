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

## Android se conecta a la red de 2,4 GHz y no a la de 5 GHz

Si el router tiene las dos redes guardadas, Android elige la que le llega con más señal, y la de 2,4 GHz suele llegar
más fuerte aunque sea mucho más lenta (en la notebook de prueba: ~15 Mbit/s con saltos de 120 ms contra ~36 Mbit/s y
7 ms en 5 GHz). Conectarse **a mano** a la de 5 GHz (Ajustes → Red, o por ADB `cmd wifi connect-network "<red 5 GHz>"
wpa3 <clave>`; `wpa2` si el router no usa WPA3) la marca como elegida y Android la prefiere. La de 2,4 GHz puede
quedar guardada como respaldo. Ver la red actual: `cmd wifi status`.

## La tele queda azul y rayada al entrar a Android TV

Pasaba cuando el cargador recibía `video=eDP-1:d video=HDMI-A-1:1920x1080@60e` (modo «solo la tele»). Desde la v1.4.0
el lanzador no manda esas órdenes: Android arranca en la notebook y `pantalla.sh` lo pasa a la tele. Las entradas
«solo la tele» del menú de GRUB siguen con `video=`: no usarlas con esta notebook.

## La tele no muestra Android (queda en negro) aunque está enchufada

Si la tele se conecta o se prende **después** de entrar a Android, Android la toma como pantalla secundaria. Lo
resuelve `pantalla.sh` (v1.4.0). Si la Batocera tampoco ve la tele al arrancar, revisar **el cable HDMI**: uno fallado
daba puntos de colores, cortes de imagen y la tele «desconectada».

## «Tu formato de video no es compatible» o videos sin sonido

No es el video: Android se quedó sin salida de sonido. Ver «Sonido por la tele» en [Cómo funciona](COMO-FUNCIONA.md)
(`hal.audio.primary.hdmi=1`). Si el servicio de sonido arrancó antes que el controlador: `setprop ctl.restart audioserver`.
No hace falta pasar el video al procesador.

## Android lento, como trabado

Calor: con el procesador fijo al máximo (`performance`) llegaba a 90 °C y se frenaba solo (miles de veces por hora;
`/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count`). `ajustes.conf` lo deja en automático
(`powersave` + `balance_performance`): 64 °C y sin frenadas. Con la tapa baja disipa peor.

## Mirando un video se reinicia la imagen de Android

Se caía `android.hardware.graphics.allocator@2.0-service` con `Scudo ERROR: internal map failure` (tope de mapeos por
programa, `vm.max_map_count` = 65530; la RAM sobraba). `ajustes.conf` lo sube a 1048576, como la Steam Deck.

## Pregunta «elegir pantalla de inicio» y se queda ahí

Pasa si Android perdió cuál es el inicio principal (por ejemplo, después de apagarlo con el botón). La revisión de
arranque lo repone y abre el inicio RS Groove: la pregunta se cierra sola.

## Un video flotante no se puede cerrar

App **«Cerrar todo»** (desde el inicio, con el celular o el joystick) o **Select + Círculo**. Para que una app no
quede flotando: Ajustes → Apps → Acceso especial de apps → Pantalla en pantalla.

## Apagué la tele a la noche y a la mañana estaba «todo apagado»

No era una suspensión: Android siguió prendido toda la noche (el reloj del núcleo no salta en `kmsg.txt` y no hay
líneas `PM: suspend`). Lo que pasó: al **prender la tele**, Android la volvió a leer mal (pasó a 1024×768) y se trabó
(`Watchdog: Blocked in monitor WindowManagerService … 66s`). En la Batocera, al prender la tele, el menú se reinicia.
**Arreglo:** la «tele fija» de la v1.5.0 ([COMO-FUNCIONA.md](COMO-FUNCIONA.md)). Para revisar una noche desde la
Batocera, sin arrancar Android: `/userdata/android-tv/data/kmsg.txt`, `log.txt` y `rsgroove/*.log`.

## El celular deja de controlar el Android TV (pide el código otra vez)

En el registro: `AtvRemote.TcpClient: Incoming connection from unknown device <IP del celular>`. Android olvidó el
emparejamiento. **Arreglo:** en la app Google TV, conectarse de nuevo y poner el código que aparece en la tele. Si pasa
seguido, fijarse si coincide con un apagado de golpe.

## Una app no tiene internet aunque pide el permiso

LineageOS deja **sin red** (política `REJECT_ALL`) a las apps que se instalaron **sin** pedir internet. Si una
actualización después lo pide, sigue bloqueada: `UnknownHostException` en la app y `blockedReasons=8` en
`dumpsys connectivity`. Pasó con el inicio cuando se le sumó el clima. **Arreglo** (con `adb root`, solo para esa app):

```sh
U=$(adb shell stat -c %u /data/data/<paquete>)
adb shell service call netpolicy 4 i32 $U          # 00040000 = bloqueada
adb shell service call netpolicy 3 i32 $U i32 262144   # le saca el bloqueo (queda guardado)
```

## Pendientes (todavía sin arreglo)

- **Bluetooth de Android** se cae en el Qualcomm QCA9377 (`LE_ADV_FILTER` en el registro).
- Widevine es **L3** en x86: algunas apps de video van en SD.
