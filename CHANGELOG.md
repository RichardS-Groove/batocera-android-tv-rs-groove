# Registro de cambios

Formato: [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versiones: `MAYOR.MENOR.ARREGLO`
(cambio grande / mejora nueva / arreglo chico).

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
