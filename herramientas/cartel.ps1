param([string]$Logo, [string]$Texto, [string]$Out, [string]$Fuente, [int]$Letra = 62, [int]$LogoAlto = 150,
      [ValidateSet('claro', 'oscuro')][string]$Estilo = 'claro')
# Android TV RS Groove — cartel de app para el inicio (640x360): logo a la izquierda y el nombre, centrados juntos.
# Estilo «claro» (por defecto, el que se usa): fondo blanco y letra gris, como los carteles de Google.
# Estilo «oscuro»: fondo grafito con degradé suave y letra blanca.
Add-Type -AssemblyName System.Drawing
$W = 640; $H = 360
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAliasGridFit'
$rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
if ($Estilo -eq 'oscuro') {
    $fondo = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
        [System.Drawing.Color]::FromArgb(255, 44, 46, 56), [System.Drawing.Color]::FromArgb(255, 18, 19, 24), 90.0)
    $g.FillRectangle($fondo, $rect)
    $colorTexto = [System.Drawing.Color]::FromArgb(255, 241, 243, 244)
} else {
    $g.Clear([System.Drawing.Color]::FromArgb(255, 248, 249, 250))
    $colorTexto = [System.Drawing.Color]::FromArgb(255, 60, 64, 67)
}

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($Fuente)
$font = New-Object System.Drawing.Font($pfc.Families[0], $Letra, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush $colorTexto

$img = [System.Drawing.Image]::FromFile($Logo)
$lh = $LogoAlto; $lw = [int]($img.Width * $lh / $img.Height)
$gap = 34
$sz = $g.MeasureString($Texto, $font)
$total = $lw + $gap + $sz.Width
$x = [int](($W - $total) / 2); $y = [int](($H - $lh) / 2)
$g.DrawImage($img, $x, $y, $lw, $lh)
$g.DrawString($Texto, $font, $brush, $x + $lw + $gap, [int](($H - $sz.Height) / 2))

$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose(); $g.Dispose(); $bmp.Dispose()
"ok $Out"
