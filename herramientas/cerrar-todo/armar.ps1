# Arma la app «Cerrar todo» (Android TV RS Groove, 08/11/2026) con las herramientas de C:\rsgtv (JDK 21 + SDK 34).
# Uso: powershell -ExecutionPolicy Bypass -File armar.ps1     -> C:\rsgtv\cerrartodo\cerrar-todo.apk
# La llave de firma (C:\rsgtv\cerrartodo\clave.jks) es solo de esta casa: nunca a git.
# Su clave se lee de la variable CERRAR_TODO_CLAVE (que cada uno guarda fuera de git); si no está, se usa «android»,
# la clave de prueba estándar de Android.
$ErrorActionPreference = 'Stop'
$Clave = if ($env:CERRAR_TODO_CLAVE) { $env:CERRAR_TODO_CLAVE } else { 'android' }
$Fuente = $PSScriptRoot
$W = 'C:\rsgtv\cerrartodo'
$B = 'C:\rsgtv\sdk\build-tools\34.0.0'
$J = 'C:\rsgtv\sdk\platforms\android-34\android.jar'
$env:JAVA_HOME = 'C:\rsgtv\jdk'
foreach ($d in 'obj', 'dex', 'res\drawable-xhdpi') { New-Item -ItemType Directory -Force (Join-Path $W $d) | Out-Null }

# 1) Cartel 320x180 y ícono 192x192: círculo rojo con una X blanca, texto «Cerrar todo».
Add-Type -AssemblyName System.Drawing
function Dibujar($ancho, $alto, $conTexto, $salida) {
    $bmp = New-Object System.Drawing.Bitmap $ancho, $alto
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::FromArgb(255, 24, 24, 34))
    $d = [int]($alto * 0.55); $x = if ($conTexto) { [int]($alto * 0.22) } else { [int](($ancho - $d) / 2) }; $y = [int](($alto - $d) / 2)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 220, 53, 69))), $x, $y, $d, $d)
    $lapiz = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([single]($d * 0.12))
    $lapiz.StartCap = 'Round'; $lapiz.EndCap = 'Round'
    $m = [int]($d * 0.3)
    $g.DrawLine($lapiz, $x + $m, $y + $m, $x + $d - $m, $y + $d - $m)
    $g.DrawLine($lapiz, $x + $d - $m, $y + $m, $x + $m, $y + $d - $m)
    if ($conTexto) {
        $letra = New-Object System.Drawing.Font 'Segoe UI', ([single]($alto * 0.13)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $formato = New-Object System.Drawing.StringFormat; $formato.LineAlignment = 'Center'
        $caja = New-Object System.Drawing.RectangleF ([single]($x + $d + $alto * 0.08)), 0, ([single]($ancho - $x - $d)), ([single]$alto)
        $g.DrawString('Cerrar todo', $letra, [System.Drawing.Brushes]::White, $caja, $formato)
    }
    $g.Dispose(); $bmp.Save($salida, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
Dibujar 320 180 $true (Join-Path $W 'res\drawable-xhdpi\cartel.png')
Dibujar 192 192 $false (Join-Path $W 'res\drawable-xhdpi\icono.png')

# 2) Compilar Java -> dex.
Get-ChildItem (Join-Path $W 'obj') -Recurse -File | Remove-Item
& 'C:\rsgtv\jdk\bin\javac.exe' --release 11 -classpath $J -d (Join-Path $W 'obj') (Join-Path $Fuente 'src\ar\rsgroove\cerrartodo\Cerrar.java')
if ($LASTEXITCODE) { throw 'javac falló' }
# Las clases van en un .jar: el nombre «Cerrar$1.class» se rompe al pasarlo suelto a d8.bat.
& 'C:\rsgtv\jdk\bin\jar.exe' cf (Join-Path $W 'clases.jar') -C (Join-Path $W 'obj') .
& "$B\d8.bat" --release --min-api 28 --lib $J --output (Join-Path $W 'dex') (Join-Path $W 'clases.jar')
if ($LASTEXITCODE) { throw 'd8 falló' }

# 3) Recursos + manifiesto -> apk sin código; se le suma classes.dex.
& "$B\aapt2.exe" compile --dir (Join-Path $W 'res') -o (Join-Path $W 'res.zip')
& "$B\aapt2.exe" link -I $J --manifest (Join-Path $Fuente 'AndroidManifest.xml') --min-sdk-version 28 --target-sdk-version 34 -o (Join-Path $W 'base.apk') (Join-Path $W 'res.zip')
if ($LASTEXITCODE) { throw 'aapt2 link falló' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open((Join-Path $W 'base.apk'), 'Update')
[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $W 'dex\classes.dex'), 'classes.dex') | Out-Null
$zip.Dispose()

# 4) Alinear y firmar (la llave se crea la primera vez).
& "$B\zipalign.exe" -f -p 4 (Join-Path $W 'base.apk') (Join-Path $W 'alineado.apk')
$ks = Join-Path $W 'clave.jks'
if (-not (Test-Path $ks)) {
    & 'C:\rsgtv\jdk\bin\keytool.exe' -genkeypair -keystore $ks -storepass $Clave -keypass $Clave -alias rsgroove -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=RS Groove'
}
& "$B\apksigner.bat" sign --ks $ks --ks-pass pass:$Clave --out (Join-Path $W 'cerrar-todo.apk') (Join-Path $W 'alineado.apk')
if ($LASTEXITCODE) { throw 'apksigner falló' }
Write-Output "listo: $(Join-Path $W 'cerrar-todo.apk')"
