# Registro de cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versiones: `MAYOR.MENOR.ARREGLO`
(cambio grande / mejora nueva / arreglo chico).

## [1.3.1] — 2026-11-07

### Agregado

- Receta completa para hacer el cartel de cualquier app en [docs/INICIO.md](docs/INICIO.md) (de dónde sacar
  el logo, parámetros, vista previa, cómo meterlo en el inicio) y `herramientas/hoja.ps1` para la vista previa.

### Cambiado

- El tema ya no trae los 5 personajes de neón sobre fondo negro (no gustaban): quedan los 3 paisajes de anime.
- `fondos.sh` saltea las imágenes de Wallhaven con fondo negro (los dos colores principales negros o casi negros).

### Pendiente

- Foto principal del README con un paisaje de anime (la actual muestra uno de los fondos sacados).

## [1.3.0] — 2026-11-07

### Agregado

- **Fondos nuevos cada día** ([docs/FONDOS.md](docs/FONDOS.md)) con `fondos.sh`, que lanza `arranque.sh`:
  - **Wallhaven** (principal, sin clave): arte de anime, lo más elegido, solo contenido apto, 1920×1080 o más, hasta
    4 MB; muestra de dónde es cada imagen. No se suben a ningún lado: los derechos son de sus artistas.
  - **Unsplash** (opcional, con clave gratis de cada uno): ciudades de neón, cyberpunk y Tokio de noche, con el crédito
    del fotógrafo; registra cada descarga y respeta el cupo.
  - **Reserva de hasta 90 fondos** para cuando no hay internet; los más viejos salen solos.
- **Carteles para Chrome y Drive** como los de las apps de TV (`app_banners` + `herramientas/cartel.ps1`).
- **README nuevo**, en español y en inglés, con más diseño.
- La clave de Unsplash es de cada uno: `fondos.env.example` sin clave y `fondos.env` fuera de git.

### Cambiado

- El tema ya no trae las 10 fotos del espacio de la NASA: quedan las 8 de anime de uso libre.
- Tema: de dónde es cada fondo en pantalla (`wallpaper_captions`) y un oscurecido suave (`wallpaper_dim` 15).

### Arreglado

- El `grep` de Android se cae con acentos (código 139): `fondos.sh` lee las respuestas con `awk`.
- Al refrescar los fondos, Android llegó a mostrar por un momento el inicio anterior: ahora abre el inicio por su nombre.

### Cómo se probó

- Wallhaven: lectura probada con una respuesta real en el Android; primera tanda de 28 fondos de anime en 74 s.
- Unsplash: primera tanda de 28 fotos en 70 s; frenó solo al llegar al cupo.
- Reserva y créditos: un crédito por fondo; carpeta temporal vacía al terminar.
- Carteles de Chrome y Drive vistos en el inicio.

## [1.2.0] — 2026-11-07

### Agregado

- **Nombre nuevo: «Android TV RS Groove»** (título del proyecto y nombre del equipo en la red y en el celular).
- **Inicio RS Groove** ([docs/INICIO.md](docs/INICIO.md)): el inicio estilo Apple TV de CleanYourTV (commit `d451b17`,
  armado en la PC, instalado sin apagar el inicio anterior) + **tema propio** `tema/rs-groove/`: 18 imágenes de uso
  libre que cambian cada minuto en orden aleatorio, barra con YouTube, Chrome, Drive, Play Store y Aurora, Biblioteca
  de aplicaciones.
- **El celular como control remoto** ([docs/CELULAR.md](docs/CELULAR.md)): el Android TV Remote Service no tenía
  permiso de Bluetooth y no aceptaba celulares; se le dio y abre sus puertos 6466 y 6467.
- **Chrome 157 y Google Drive 2.26** (versiones de celular), con huella y firma de Google comprobadas
  ([docs/GOOGLE.md](docs/GOOGLE.md)).
- Problemas nuevos con su arreglo en [docs/PROBLEMAS.md](docs/PROBLEMAS.md).

### Cómo se probó

- Inicio: instalado y puesto como inicio en el equipo de prueba; fotos con tres imágenes distintas en tres minutos;
  Chrome y Drive en la barra después de sumar `library_apps`.
- Control remoto: el servicio abrió 6466 y 6467 y el permiso quedó dado; falta emparejar un celular.
- Chrome abrió en español y vio la cuenta; Drive abrió.

## [1.1.1] — 2026-11-07

### Arreglado

- Guía de instalación, paso 11: el `adb push` del teclado usaba la ruta de la Batocera (`$P`); se corre desde la
  carpeta del proyecto en la PC.

## [1.1.0] — 2026-11-07

### Agregado

- **Volumen con la palanca derecha**, como en la Batocera (`arranque.sh`): arriba sube, abajo baja; sostenida repite
  (unas 4 a 5 veces por segundo; cada paso tarda ~175 ms). Zona muerta: de 60 a 195 sobre 0–255.
- **`herramientas/teclado-espanol.sh`**: teclado de la notebook en español (Latinoamérica por defecto, o España).
  Android 14 ponía «Inglés (EE. UU.)» y lo volvía a poner al arrancar; pasa al modo clásico, donde el diseño queda
  guardado.
- Documentación: cómo volver a lanzar `arranque.sh` sin reiniciar (`setprop ctl.restart kmsg_fetch`), el teclado,
  y que la palanca derecha también cambia el volumen dentro de los juegos.

### Cómo se probó

- Volumen: con movimientos simulados de la palanca en el Android real (arriba 0,8 s → 4 pasos, abajo 0,6 s → 3
  pasos, al soltar para) y ya activo en el equipo. Falta la prueba con la palanca de verdad.
- Teclado: el diseño «Español (Latinoamérica)» quedó guardado después de reiniciar la interfaz (antes volvía a
  inglés). La receta se probó frenando ante un diseño que no existe; la parte que escribe repite los comandos que
  se usaron a mano. Falta que la persona escriba con el teclado.

## [1.0.0] — 2026-11-07

Primera versión publicada. Todo probado en una Dell Inspiron 3493 con Batocera 43.1 y LineageOS 21 Android TV
x86_64 `20260331`.

### Agregado

- Sistema **«Android TV»** en el menú de la Batocera (`es_systems_android.cfg`, `gamelist.xml`).
- **Lanzador** `Android TV.sh`: comprueba la entrada UEFI y los archivos, elige la pantalla (tele por HDMI o la de la
  notebook), arma `BootNext` y reinicia limpio con `batocera-es-swissknife --reboot`. Registro en `lanzador.log`.
- **`grub.cfg`** propio: Android TV automático, solo la tele, solo la notebook, sin asistente inicial, video seguro y
  volver a la Batocera. Zona horaria desde el arranque (`SET_TZ_LOCATION`).
- **Arranque propio** (`scripts/9-rsgroove` + `rsgroove/init.sh` + `arranque.sh`): cualquier reinicio vuelve a la
  Batocera (`BootNext`), ADB por red en el puerto 5555 y atajo **Select + Start** para volver a la Batocera.
- **`herramientas/generar-init.sh`**: genera nuestro `init.sh` desde el original de Android (2 líneas). Probado en la
  PC y en Android: da un archivo idéntico, byte por byte, al que funciona.
- **Botones como en la Batocera** para el joystick ShanWan `2563:0523`: Cruz acepta, Círculo vuelve, Select va al
  inicio de Android.
- **Sistema modificable**: `system.img` (ext4) en lugar de `system.efs`, con `fstab.android`.
- Documentación en español: instalación, Google Play (microG + Play Store x86_64), control por ADB, cómo funciona y
  problemas conocidos. README en inglés.
- Fotos del inicio de Android TV y de la Play Store (sin datos de la cuenta).
- Licencia **Creative Commons BY-NC-SA 4.0**, la misma del tema RS Groove: se puede modificar dando crédito, con la
  misma licencia y sin uso comercial.

### Sin probar todavía

- Copiar el `init.sh` original desde el `system.img` montado en la Batocera (en el equipo de prueba salió por ADB).
- Desinstalar.
