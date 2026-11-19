# Generates the original app icon (1024x1024, opaque PNG) with plain shapes only:
# a blue gradient and a stylised gauge. No logos, no fonts.
# Run on Windows:  powershell -ExecutionPolicy Bypass -File tools/make-icon.ps1
param(
    [string]$Out = "$PSScriptRoot/../Peugeot408/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)
Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Background: deep navy -> accent blue (#1F4FD8)
$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
    [System.Drawing.Color]::FromArgb(255, 10, 18, 52),
    [System.Drawing.Color]::FromArgb(255, 31, 79, 216), 60.0)
$g.FillRectangle($bg, $rect)

# Gauge track (270 degree arc)
$arcRect = New-Object System.Drawing.Rectangle(212, 232, 600, 600)
$track = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 255, 255, 255), 64)
$track.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$track.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($track, $arcRect, 135, 270)

# Gauge value arc
$value = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 64)
$value.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$value.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($value, $arcRect, 135, 190)

# Needle from centre towards the end of the value arc
$cx = 512; $cy = 532
$angle = (135 + 190) * [Math]::PI / 180
$len = 230
$needle = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 34)
$needle.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$needle.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($needle, $cx, $cy, [int]($cx + $len * [Math]::Cos($angle)), [int]($cy + $len * [Math]::Sin($angle)))

# Hub
$hub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillEllipse($hub, $cx - 52, $cy - 52, 104, 104)
$hubInner = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 31, 79, 216))
$g.FillEllipse($hubInner, $cx - 22, $cy - 22, 44, 44)

$dir = Split-Path -Parent $Out
New-Item -ItemType Directory -Force $dir | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "Wrote $Out"
