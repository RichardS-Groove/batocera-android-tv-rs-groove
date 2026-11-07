# Google Play en Android TV (liviano, sin traductor)

LineageOS no trae Google. En este equipo se probaron dos caminos; quedó el liviano.

| Camino | Resultado en el equipo de prueba |
| --- | --- |
| MindTheGapps ATV (Google Play Services original) | **Descartado.** Google Play Services corría traducido de ARM (libhoudini), al **700 % de CPU** y con avisos de «no responde». Además faltaba el asistente de cuenta (SetupWraith). |
| **NotSoGapps ATV (microG)** + **Play Store de Android TV x86_64** | **El que quedó.** Inicio de sesión de Google andando, la Play Store carga las carátulas y Android entero usa ~5 % de CPU. |

Hace falta el sistema modificable (`system.img`, paso 7 de [INSTALAR.md](INSTALAR.md)) y ADB como root.

## 1. NotSoGapps ATV x86_64 (microG)

Archivo (GitHub de `supremegamers`, compilación para LineageOS-TV-x86):

- <https://github.com/supremegamers/NSG-14.0.0-x86_64-ATV/releases/download/NotSoGapps-14.0.0-x86_64-ATV-minimal-20250624_165026/NotSoGapps-14.0.0-x86_64-ATV-minimal-20250625_183937.zip>
- sha256 `8283d63bc29e6bf6f364632ed9d92353f8b54af0f5f95d5ab0fce74ef9f48028`

Se instala igual que lo hace su propio `update-binary`:

- `system/system/*` → `/system/`, `system/product/*` → `/system/product/`, `system/system_ext/*` → `/system/system_ext/`;
- carpetas `755`, archivos `644` (los `.sh` y los que no tienen extensión, `755`), dueño `root:root`, contexto
  `system_file`.

Con Android prendido y ADB como root: `adb shell mount -o remount,rw /`, copiar, `restorecon -R` sobre lo copiado y
reiniciar. Trae microG (`GmsCore`), `GsfProxy`, la Play Store de TV (`Tubesky`), `Backdrop`, `Katniss` y otros.

**Katniss** (el asistente de voz) gastaba CPU sin parar. Se apaga sin borrarlo:

```bash
adb shell pm disable-user com.google.android.katniss
```

## 2. microG al día (0.3.17 o más nuevo)

Con el microG que trae NotSoGapps, al iniciar sesión salía **«Hubo un problema comunicándose con los servidores de
Google»** y en el registro `MissingDroidguard`. Está arreglado en microG **0.3.13+** (microG PR #3257 y #3350).

- microG oficial: <https://github.com/microg/GmsCore/releases> — en el equipo de prueba, **0.3.17.252432**
  (`com.google.android.gms-252432034.apk`, sha256
  `e5e6cba078bdec812b5450599350e5c1a12c8b7438da5bf77123af170f8c1a35`).
- **Comprobá la huella antes de instalar**: `sha256sum` del archivo contra la publicada.

```bash
adb install -r com.google.android.gms-252432034.apk
```

## 3. Ajustes de microG

Se cambian por ADB (o en la app *Ajustes de microG*). Los sí/no van como **`b:true`**; con `i:1` algunos no toman.

```bash
U=content://com.google.android.gms.microg.settings
adb shell content update --uri $U/check-in   --bind checkin_enable_service:i:1
adb shell content update --uri $U/gcm        --bind gcm_enable_mcs_service:b:true
adb shell content update --uri $U/safety-net --bind safetynet_enabled:b:true
adb shell content update --uri $U/droidguard --bind droidguard_enabled:b:true
adb shell content update --uri $U/droidguard --bind droidguard_mode:s:Embedded
adb shell 'am force-stop com.google.android.gms; am force-stop com.android.vending'
```

Si el registro dice **«Attempt to load writable dex»** (DroidGuard): el archivo que baja DroidGuard tiene que ser de
solo lectura.

```bash
adb shell 'find /data/data/com.google.android.gms/app_cache_dg -name the.apk -exec chmod 444 {} \;'
```

Después, iniciar sesión desde la Play Store con **Acceder**.

## 4. Play Store de Android TV para x86_64

La Play Store que trae NotSoGapps (`Tubesky`, 39.4.25) **solo tiene piezas ARM**: corre por el traductor y en el
equipo de prueba usaba **790 % de 800 %** de CPU, sin tiempo para bajar las carátulas. La de Android TV **53.4.17**
trae piezas **x86_64** y corre sin traductor.

- APKMirror, «Google Play Store (Android TV) 53.4.17-34 [8] [PR] 988500596», variante
  `arm64-v8a + armeabi-v7a + x86 + x86_64`, `nodpi`, Android 14+:
  <https://www.apkmirror.com/apk/google-inc/google-play-store-android-tv/google-play-store-android-tv-53-4-17-release/>
- Archivo de 55.885.570 bytes, sha256 `0425799b8cc6b9e1e0f683dc234759754c15537daa7558d6915a474383c0c3a1`.
- Firma: el certificado v2 es **el mismo de Google** que el de la Play Store instalada
  (`f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83`); el v3 es la llave nueva de Google
  (`7ce83c1b…`). Si no coincidiera, Android rechaza la instalación.

```bash
adb install -r vending-53.4.17-34.apk
adb shell 'dumpsys package com.android.vending | grep -E "primaryCpuAbi|versionName"'
# primaryCpuAbi=x86_64  versionName=53.4.17-34 …
```

Se instala como **actualización**: la Play Store del sistema queda guardada. Para volver atrás:

```bash
adb shell pm uninstall-system-updates com.android.vending
```

En el registro quedan avisos como «cannot get user data for accounts of type com.google» y «More than one auth
provider»: son de microG con la Play Store y, en el equipo de prueba, no tuvieron efecto visible.

## Chrome y Google Drive (versiones de celular)

Esta compilación es «solo TV» (`android.software.leanback_only`): la Play Store muestra solo apps hechas para tele, y
**Google no publica Chrome ni Drive para Android TV**. Se instalan las versiones oficiales de celular desde APKMirror,
comprobando huella y firma igual que la Play Store:

| App | Variante | sha256 del archivo | Firma | Corre como |
| --- | --- | --- | --- | --- |
| Chrome 157.0.8103.46 | APK `x86`, Android 10+ (262.133.409 bytes) | `fdf6b5600a3c964f90a698c95830e509c228766bb26e3a662603968b8ec3630f` | Google `f0fd6c5b…db83` (v2 y v3) | `x86`, sin traductor |
| Drive 2.26.447.0 | APK universal, Android 8+ (131.916.009 bytes) | `e1a53ac11f3018fb695eecd40180fc540fbcd73d5258cda8f653bbbf934cd4a3` | Google `f0fd6c5b…db83` | `x86_64` |

- Esa versión de Chrome no tenía variante `x86_64`; la `x86` corre igual sin traductor. **No pidió** la biblioteca
  Trichrome.
- Chrome abre en español y ya ve la cuenta de microG (la sincronización la elige cada uno).
- **No se actualizan solas** desde la Play Store de la tele: para actualizar, bajar la nueva y `adb install -r`.
- Se manejan mejor con touchpad y teclado que con el joystick.
- Para que aparezcan en el inicio RS Groove: `library_apps` del tema (ver [INICIO.md](INICIO.md)).

## Aurora Store (opcional)

Aurora (<https://f-droid.org/packages/com.aurora.store/>) **no usa** la cuenta de microG: tiene su propio ingreso
(Google o Anónimo). Con la Play Store andando, queda como respaldo.

## Lo que no hay en x86

Widevine es nivel **L3**: Netflix, Prime Video y Disney+ pueden ir en calidad SD o con su versión para celular.
