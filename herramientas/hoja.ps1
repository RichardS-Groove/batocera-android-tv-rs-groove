param([string]$Dir, [string]$Out, [string[]]$Files)
Add-Type -AssemblyName System.Drawing
$W = 480; $H = 270; $cols = 4
$rows = [math]::Ceiling($Files.Count / $cols)
$sheet = New-Object System.Drawing.Bitmap ($W * $cols), (($H + 24) * $rows)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::White)
$font = New-Object System.Drawing.Font 'Segoe UI', 11
for ($i = 0; $i -lt $Files.Count; $i++) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $Dir $Files[$i]))
    $x = ($i % $cols) * $W; $y = [math]::Floor($i / $cols) * ($H + 24)
    $g.DrawImage($img, $x, $y + 24, $W, $H)
    $g.DrawString($Files[$i], $font, [System.Drawing.Brushes]::Black, $x + 4, $y + 2)
    $img.Dispose()
}
$sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose()
"ok"
