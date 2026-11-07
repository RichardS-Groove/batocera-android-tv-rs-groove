# 🖼️ Fondos nuevos cada día

El inicio RS Groove (CleanYourTV) no tiene permiso de internet: no puede bajar imágenes solo. `fondos.sh` las baja por
él y las suma a los 3 paisajes de anime del tema, que van cambiando cada minuto. Guarda una **reserva de hasta 90 fondos**:
sin internet, siguen pasando esos.

| Fuente | Qué trae | Clave |
| --- | --- | --- |
| **Wallhaven** (principal) | Arte de anime: lo más elegido de [wallhaven.cc](https://wallhaven.cc), paisajes, ciudades, atardeceres, cerezos, lluvia y calles. Solo contenido apto, 1920×1080 o más, 16:9, hasta 4 MB. | No hace falta |
| **Unsplash** (opcional) | Fotos de ciudades de neón, cyberpunk y Tokio de noche, ya cortadas en 1920×1080, con el crédito del fotógrafo. | Gratis, de cada uno |

> [!IMPORTANT]
> **El arte de Wallhaven es de sus artistas.** Se baja para verlo en tu propia tele y nunca se sube a ningún lado (este
> repositorio no trae ninguna imagen de Wallhaven). El inicio muestra de dónde es cada una («Arte: pixiv.net/…»).
>
> **La clave de Unsplash es de cada uno y es privada.** Este repositorio no trae ninguna: cada persona saca la suya y la
> guarda en su equipo (`fondos.env`, que git ignora). Nunca la subas a GitHub ni la pegues en un chat.

## Cómo funciona

1. `arranque.sh` lanza `fondos.sh --vigilar` en cada encendido; da una vuelta por hora.
2. Mientras la reserva tenga menos de `FONDOS_GUARDAR` (90), baja una tanda por vuelta. Llena, suma una tanda cada
   `FONDOS_CADA_HORAS` (24) y saca los más viejos.
3. **Wallhaven:** busca en la [API de Wallhaven](https://wallhaven.cc/help/api) solo anime (`categories=010`), solo apto
   (`purity=100`), por favoritos, con 1920×1080 o más y 16:9. Cambia de página cada día para variar. Respeta su límite
   (45 pedidos por minuto).
4. **Unsplash:** pide fotos al azar a su API, las baja en 1920×1080, **registra cada descarga** (lo piden sus reglas) y
   respeta el cupo de la clave gratis (50 pedidos por hora: si queda poco, sigue en la vuelta siguiente).
5. **Sin fondos negros:** saltea las imágenes de Wallhaven cuyos dos colores principales son negros o casi negros
   (personajes sobre fondo negro); las que solo tienen siluetas oscuras se quedan.
6. Comprueba que cada archivo sea una imagen de verdad, la pasa al inicio por su proveedor, deja un crédito por fondo
   y vuelve a abrir el inicio si está en pantalla. Sin internet no cambia nada.

Registro: `/data/rsgroove/fondos.log` (la clave nunca se escribe ahí). Créditos: `/data/rsgroove/fondos-creditos.txt`.

## Configurarlo

En la Batocera, copiar [`android-tv/data/rsgroove/fondos.env.example`](../android-tv/data/rsgroove/fondos.env.example)
a `/userdata/android-tv/data/rsgroove/fondos.env` (= `/data/rsgroove/fondos.env` en Android), dueño root, permisos
`600`. Sin ese archivo, `fondos.sh` no hace nada.

| Ajuste | Para qué |
| --- | --- |
| `FONDOS_FUENTES` | `"wallhaven"`, `"unsplash"` o `"wallhaven unsplash"` |
| `FONDOS_CANTIDAD_WALLHAVEN` / `FONDOS_CANTIDAD_UNSPLASH` | Cuántos de cada uno por tanda (24 y 6) |
| `WALLHAVEN_BUSQUEDAS` / `FONDOS_BUSQUEDAS` | Qué buscar en cada uno, separado por `\|` |
| `FONDOS_GUARDAR` | Tamaño de la reserva (90; cada fondo pesa entre 0,5 y 4 MB) |
| `FONDOS_CADA_HORAS` | Cada cuánto se renueva cuando la reserva está llena |
| `UNSPLASH_ACCESS_KEY` | Solo para Unsplash |

### La clave de Unsplash (solo si la querés)

1. Crear una cuenta en <https://unsplash.com/join>.
2. <https://unsplash.com/oauth/applications> → **New Application**, aceptar las condiciones y ponerle un nombre.
3. Copiar la **Access Key** (no la Secret Key) y pegarla en `fondos.env`, después de `UNSPLASH_ACCESS_KEY=`.

## Probarlo ya

```bash
adb root
adb shell sh /data/rsgroove/fondos.sh --ya
adb shell tail /data/rsgroove/fondos.log
```

## Detalles técnicos

- El `grep` de Android (toybox) **se cae** con textos con acentos (código 139): `fondos.sh` lee las respuestas con `awk`.
- Wallhaven escribe las direcciones como `https:\/\/…`: se corrigen antes de bajar.
- El inicio achica cada imagen al mostrarla (`inSampleSize`), así que las 4K no gastan memoria de más.
- Al terminar abre el inicio **por su nombre** (`am start -n com.gathin.tvhome/.MainActivity`): pidiendo «el inicio» en
  general, Android llegó a mostrar por un momento otro inicio instalado.
- Pruebas sin red: `fondos.sh --probar-wallhaven respuesta.json` y `fondos.sh --probar-json respuesta.json`.
- La carpeta temporal se borra con su ruta escrita entera, nunca con `rm -rf` y una variable.
