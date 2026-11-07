#!/system/bin/sh
# Android TV RS Groove — fondos nuevos para el inicio (CleanYourTV, com.gathin.tvhome).
#
# Fuentes (FONDOS_FUENTES):
#   wallhaven  arte de anime de Wallhaven (wallhaven.cc), lo más elegido, solo contenido apto, 1920x1080 o más.
#              Sin clave. Los derechos son de cada artista: uso personal, nunca se suben a ningún lado.
#   unsplash   fotos de Unsplash ya cortadas en 1920x1080, con el crédito del fotógrafo. Necesita una clave gratis
#              (UNSPLASH_ACCESS_KEY), que es de cada uno y nunca va a git.
#
# Lo lanza arranque.sh en cada encendido (--vigilar: una vuelta por hora). Guarda una reserva de hasta
# FONDOS_GUARDAR fondos (varios días), así sin internet siempre hay muchos. Mientras haya menos, baja una tanda por
# vuelta; llena, suma una tanda cada FONDOS_CADA_HORAS y saca los más viejos. Si algo falla, quedan los que había.
#
# Uso a mano (root):  sh /data/rsgroove/fondos.sh --ya                 una tanda ya, sin mirar la hora
#                     sh /data/rsgroove/fondos.sh --probar-json F      lee una respuesta guardada de Unsplash
#                     sh /data/rsgroove/fondos.sh --probar-wallhaven F lee una respuesta guardada de Wallhaven
# Configuración: /data/rsgroove/fondos.env (root, 600), ver fondos.env.example.

R=/data/rsgroove
CONF=$R/fondos.env
LOG=$R/fondos.log
EST=$R/fondos.ultima
CRED=$R/fondos-creditos.txt
PKG=com.gathin.tvhome
URI=content://$PKG.theme
DIR=/sdcard/Android/data/$PKG/files
TMP=/data/local/tmp/rsg-fondos
API=https://api.unsplash.com
WH=https://wallhaven.cc/api/v1/search
UA="AndroidTV-RS-Groove/1.3"
TAB=$(printf '\t')

log() { echo "$(date '+%F %T') $*" >> $LOG; }

# Borra solo la carpeta temporal de este script, con la ruta escrita entera (nunca rm -rf con una variable).
limpiar() {
	rm -f /data/local/tmp/rsg-fondos/nuevas/* /data/local/tmp/rsg-fondos/* 2>/dev/null
	rmdir /data/local/tmp/rsg-fondos/nuevas /data/local/tmp/rsg-fondos 2>/dev/null
}

# Valor de texto que sigue a la clave $1 (por ejemplo "raw":") en la línea; con $2, solo después de esa otra clave.
# Con awk y no con grep: el grep de Android se cae (código 139) con nombres con acentos.
campo() {
	awk -v k="$1" -v d="$2" '{ s = $0
		if (d != "") { i = index(s, d); if (!i) exit; s = substr(s, i + length(d)) }
		i = index(s, k); if (!i) exit; s = substr(s, i + length(k)); j = index(s, "\""); print substr(s, 1, j - 1); exit }'
}

# Número que sigue a la clave $1 (por ejemplo "file_size":).
numero() {
	awk -v k="$1" '{ i = index($0, k); if (!i) exit; s = substr($0, i + length(k)); match(s, /^[0-9]+/); print substr(s, 1, RLENGTH); exit }'
}

# Unsplash. Una línea por foto: id<TAB>url de la imagen<TAB>url para registrar la descarga<TAB>fotógrafo
leer_json() {
	sed 's/},{"id":"/}\
{"id":"/g' "$1" | while IFS= read -r l; do
		raw=$(printf '%s\n' "$l" | campo '"raw":"' | sed 's/\\u0026/\&/g')
		dl=$(printf '%s\n' "$l" | campo '"download_location":"' | sed 's/\\u0026/\&/g')
		nom=$(printf '%s\n' "$l" | campo '"name":"' '"username":"')
		[ -n "$raw" ] && [ -n "$dl" ] || continue
		id=$(printf '%s\n' "$dl" | sed 's#.*/photos/##; s#/download.*##' | tr -cd 'A-Za-z0-9_-')
		[ -n "$id" ] || continue
		printf '%s\t%s\t%s\t%s\n' "$id" "$raw" "$dl" "${nom:-Unsplash}"
	done
}

# Wallhaven. Una línea por imagen: id<TAB>url de la imagen<TAB>tamaño en bytes<TAB>de dónde es (sitio/usuario)<TAB>
# los dos colores principales («#000000,#333333»)
leer_wallhaven() {
	sed 's/},{"id":"/}\
{"id":"/g' "$1" | while IFS= read -r l; do
		id=$(printf '%s\n' "$l" | campo '"id":"' | tr -cd 'A-Za-z0-9')
		path=$(printf '%s\n' "$l" | campo '"path":"' | sed 's#\\/#/#g')
		tam=$(printf '%s\n' "$l" | numero '"file_size":')
		src=$(printf '%s\n' "$l" | campo '"source":"' | sed 's#\\/#/#g; s#^https*://##; s#^www\.##' | cut -d/ -f1-2)
		col=$(printf '%s\n' "$l" | awk '{ i = index($0, "\"colors\":["); if (!i) exit; s = substr($0, i + 10)
			j = index(s, "]"); s = substr(s, 1, j - 1); gsub(/"/, "", s); split(s, a, ","); print a[1] "," a[2]; exit }')
		[ -n "$id" ] && [ -n "$path" ] || continue
		printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$path" "${tam:-0}" "$src" "$col"
	done
}

if [ "$1" = "--probar-json" ]; then leer_json "$2"; exit 0; fi
if [ "$1" = "--probar-wallhaven" ]; then leer_wallhaven "$2"; exit 0; fi

if [ "$1" = "--vigilar" ]; then
	while :; do sh "$0"; sleep 3600; done
fi

[ -r "$CONF" ] || exit 0
. "$CONF"
FUENTES=${FONDOS_FUENTES:-wallhaven}
CANT_WH=${FONDOS_CANTIDAD_WALLHAVEN:-24}
CANT_US=${FONDOS_CANTIDAD_UNSPLASH:-6}
HORAS=${FONDOS_CADA_HORAS:-24}
GUARDAR=${FONDOS_GUARDAR:-90}
WH_BUSQ=${WALLHAVEN_BUSQUEDAS:-"scenery|landscape|cityscape|sunset|cherry blossom|rain|street"}
WH_MAX=${WALLHAVEN_MAX_BYTES:-4194304}
US_BUSQ=${FONDOS_BUSQUEDAS:-"neon city night|cyberpunk|tokyo night"}

hay_fondos() { ls "$DIR"/wallpapers/ 2>/dev/null | grep -c -E '^(unsplash|wallhaven)-'; }

ahora=$(date +%s)
hay=$(hay_fondos)
if [ "$1" != "--ya" ] && [ "$hay" -ge "$GUARDAR" ] && [ -r "$EST" ] && [ $((ahora - $(cat "$EST"))) -lt $((HORAS * 3600)) ]; then exit 0; fi

i=0
until curl -s -o /dev/null -m 10 https://wallhaven.cc; do
	i=$((i + 1)); [ $i -ge 30 ] && { log "sin internet: quedan los $hay fondos guardados"; exit 1; }
	sleep 10
done
log "buscando fondos nuevos (hay $hay de $GUARDAR; fuentes: $FUENTES)"
limpiar; mkdir -p "$TMP/nuevas"

# Las búsquedas de $1 (separadas por |), una por línea, y cuántas imágenes le tocan a cada una para juntar $2.
busquedas() { printf '%s\n' "$1" | tr '|' '\n' | grep -v '^ *$'; }
por_busqueda() { n=$(busquedas "$1" | grep -c .); [ "$n" -gt 0 ] || n=1; echo $(( ($2 + n - 1) / n )); }

bajar_wallhaven() {
	[ "$CANT_WH" -gt 0 ] || return 0
	por=$(por_busqueda "$WH_BUSQ" "$CANT_WH")
	pag=$(( ahora / 86400 % 3 + 1 ))          # cambia de página cada día: más variedad
	busquedas "$WH_BUSQ" | while IFS= read -r q; do
		qq=$(printf '%s' "$q" | sed 's/ /+/g')
		curl -s -m 30 -A "$UA" -o "$TMP/w.json" \
			"$WH?q=$qq&categories=010&purity=100&sorting=favorites&atleast=1920x1080&ratios=16x9&page=$pag"
		grep -q -F '"path"' "$TMP/w.json" 2>/dev/null || { log "Wallhaven «$q»: sin resultados"; sleep 2; continue; }
		leer_wallhaven "$TMP/w.json" > "$TMP/wl.txt"
		k=0
		while IFS="$TAB" read -r id path tam src col; do
			[ $k -ge "$por" ] && break
			# Fondo negro (los dos colores principales negros o casi): no, pedido de la persona.
			case "$col" in "#000000,#000000"|"#000000,#333333"|"#000000,#424153"|"#000000,") continue ;; esac
			[ "$tam" -gt 0 ] && [ "$tam" -le "$WH_MAX" ] || continue
			ext=${path##*.}; case "$ext" in jpg|jpeg|png) ;; *) continue ;; esac
			b="wallhaven-$id.$ext"; f="$TMP/nuevas/$b"
			{ [ -f "$f" ] || [ -e "$DIR/wallpapers/$b" ]; } && continue
			curl -s -m 120 -A "$UA" -o "$f" "$path" || { rm -f "$f"; continue; }
			m=$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')
			case "$m" in ffd8*|89504e47) ;; *) rm -f "$f"; continue ;; esac
			printf '%s\tArte: %s · Wallhaven\n' "$b" "${src:-anime}" >> "$TMP/nuevas/creditos.txt"
			k=$((k + 1))
		done < "$TMP/wl.txt"
		sleep 2                                   # la API de Wallhaven admite 45 pedidos por minuto
	done
}

bajar_unsplash() {
	[ "$CANT_US" -gt 0 ] && [ -n "$UNSPLASH_ACCESS_KEY" ] || return 0
	por=$(por_busqueda "$US_BUSQ" "$CANT_US"); [ "$por" -gt 30 ] && por=30
	busquedas "$US_BUSQ" | while IFS= read -r q; do
		# Cupo de Unsplash (50 pedidos por hora con la clave gratis): cada foto gasta 1 más (registro de descarga).
		if [ -r "$TMP/quedan" ] && [ "$(cat "$TMP/quedan")" -lt $((por + 3)) ]; then
			log "cupo de Unsplash casi lleno ($(cat "$TMP/quedan")): sigo en la próxima vuelta"; break
		fi
		qq=$(printf '%s' "$q" | sed 's/ /%20/g')
		curl -s -m 30 -D "$TMP/h.txt" -o "$TMP/r.json" -H "Authorization: Client-ID $UNSPLASH_ACCESS_KEY" -H "Accept-Version: v1" \
			"$API/photos/random?count=$por&orientation=landscape&content_filter=high&query=$qq"
		awk -F': ' 'tolower($1) == "x-ratelimit-remaining" { print $2 + 0 }' "$TMP/h.txt" > "$TMP/quedan"
		[ -s "$TMP/quedan" ] || echo 0 > "$TMP/quedan"
		grep -q -F '"download_location"' "$TMP/r.json" 2>/dev/null || { log "Unsplash «$q»: sin fotos ($(head -c 120 "$TMP/r.json" 2>/dev/null))"; continue; }
		leer_json "$TMP/r.json" > "$TMP/lista.txt"
		while IFS="$TAB" read -r id raw dl nom; do
			f="$TMP/nuevas/unsplash-$id.jpg"
			{ [ -f "$f" ] || [ -e "$DIR/wallpapers/unsplash-$id.jpg" ]; } && continue
			curl -s -m 60 -o "$f" "$raw&w=1920&h=1080&fit=crop&crop=entropy&q=82&fm=jpg" || { rm -f "$f"; continue; }
			[ "$(head -c 2 "$f" | od -An -tx1 | tr -d ' \n')" = "ffd8" ] || { rm -f "$f"; continue; }
			curl -s -m 20 -o /dev/null -H "Authorization: Client-ID $UNSPLASH_ACCESS_KEY" -H "Accept-Version: v1" "$dl"
			echo $(( $(cat "$TMP/quedan") - 1 )) > "$TMP/quedan"
			printf '%s\tFoto: %s · Unsplash\n' "unsplash-$id.jpg" "$nom" >> "$TMP/nuevas/creditos.txt"
		done < "$TMP/lista.txt"
	done
}

for fuente in $FUENTES; do
	case "$fuente" in
		wallhaven) bajar_wallhaven ;;
		unsplash) bajar_unsplash ;;
		*) log "fuente desconocida: $fuente" ;;
	esac
done

total=$(ls "$TMP"/nuevas/ 2>/dev/null | grep -c -E '^(unsplash|wallhaven)-')
if [ "$total" -lt 1 ]; then log "no bajó fondos nuevos: quedan los $hay guardados"; limpiar; exit 1; fi

# Créditos: la primera vez, los que ya mostraba el inicio; después se suman los nuevos.
[ -r "$CRED" ] || cp "$DIR/wallpapers/captions.txt" "$CRED" 2>/dev/null || : > "$CRED"
cat "$TMP/nuevas/creditos.txt" >> "$CRED"

# Poner los nuevos por el proveedor del inicio (quedan a su nombre) y sacar los más viejos si pasan de GUARDAR.
ls "$TMP"/nuevas/ | grep -E '^(unsplash|wallhaven)-' | while IFS= read -r b; do
	rm -f "$DIR/wallpapers/$b"
	content write --uri "$URI/wallpapers/$b" < "$TMP/nuevas/$b"
done
sobran=$(( $(hay_fondos) - GUARDAR ))
if [ "$sobran" -gt 0 ]; then
	ls -tr "$DIR"/wallpapers/unsplash-* "$DIR"/wallpapers/wallhaven-* 2>/dev/null | head -n "$sobran" | while IFS= read -r v; do
		b=$(basename "$v"); rm -f "$v"; content delete --uri "$URI/wallpapers/$b" 2>/dev/null
	done
fi

# Créditos solo de los fondos que quedaron, uno por fondo.
ls "$DIR"/wallpapers/ | grep -E '^(unsplash|wallhaven)-' > "$TMP/estan.txt"
awk -F'\t' 'NR == FNR { e[$1] = 1; next } ($1 in e) && !v[$1]++' "$TMP/estan.txt" "$CRED" > "$TMP/cred.txt"
cat "$TMP/cred.txt" > "$CRED"
rm -f "$DIR/wallpapers/captions.txt"
content write --uri "$URI/wallpapers/captions.txt" < "$CRED"

# Que el inicio vuelva a leer la carpeta. Si está en pantalla, se vuelve a abrir; si no, al próximo Inicio.
if dumpsys activity activities 2>/dev/null | grep -m1 topResumedActivity | grep -q "$PKG/"; then
	am force-stop "$PKG"; am start -n "$PKG/.MainActivity" >/dev/null 2>&1   # por su nombre: si no, Android puede abrir otro inicio
else
	am force-stop "$PKG"
fi
echo "$ahora" > "$EST"
log "listo: $total fondos nuevos, quedan $(wc -l < "$TMP/estan.txt") guardados"
limpiar
