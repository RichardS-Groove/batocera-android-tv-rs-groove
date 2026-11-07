# Controlar Android TV desde el celular

Con la app oficial **Google TV** (Android o iPhone), por la red Wi-Fi: flechas, aceptar, volver, volumen y teclado.

## Usarlo

1. El celular en **la misma red Wi-Fi** que el equipo.
2. App **Google TV** → botón **Control remoto** → elegir **«Android TV RS Groove»**.
3. Escribir en el celular el código que aparece en la tele.

## Lo que hubo que arreglar

El que atiende al celular es el **Android TV Remote Service** (`com.google.android.tv.remote.service`, versión 5.2,
viene con NotSoGapps). Estaba corriendo pero **no abría sus puertos** (6466 y 6467). En el registro:

```text
AtvRemote.KeyStoreManager: Failed to initialize KeyStore
java.lang.SecurityException: Need android.permission.BLUETOOTH_CONNECT permission
AtvRemote.RemoteService: Key store manager is not initialized. Pairing server is down.
```

Arma la llave de emparejamiento con la dirección del Bluetooth y no tenía permiso para leerla (en un Android TV de
fábrica viene dado). Arreglo:

```bash
for p in BLUETOOTH_CONNECT BLUETOOTH_SCAN BLUETOOTH_ADVERTISE; do
  adb shell pm grant com.google.android.tv.remote.service android.permission.$p
done
adb shell 'am force-stop com.google.android.tv.remote.service; am broadcast -a android.intent.action.BOOT_COMPLETED -n com.google.android.tv.remote.service/.BootReceiver'
```

Comprobar que escucha (con root): `adb shell 'cat /proc/net/tcp6 /proc/net/tcp | grep -E ":(1942|1943) .* 0A"'`
(1942 y 1943 son 6466 y 6467 en hexadecimal). El permiso queda guardado después de reiniciar.

## El nombre que ve el celular

Venía como un código del equipo, difícil de reconocer. Se cambió:

```bash
adb shell settings put global device_name "Android TV RS Groove"
adb shell settings put secure bluetooth_name "Android TV RS Groove"
```

Después, reiniciar el servicio como arriba para que lo anuncie con el nombre nuevo.

**Si el celular ya estaba emparejado**, la app Google TV sigue mostrando el nombre que tenía al emparejar. En la app:
tocar el nombre del equipo arriba del control → desconectar u olvidar → buscar de nuevo → «Android TV RS Groove» →
código nuevo. Para comprobar qué anuncia Android: `adb shell dumpsys servicediscovery | grep androidtvremote`.

El modelo que informa Android (`ro.product.model`) y el nombre del Bluetooth siguen siendo el código de la placa de la
notebook. No se cambian: el modelo es parte de cómo Google Play reconoce el equipo.
