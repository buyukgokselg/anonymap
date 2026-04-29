Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'assets\app_icon\pulsecity_app_icon_source.png'
$baseOutputPath = Join-Path $projectRoot 'assets\app_icon\pulsecity_app_icon_1024.png'

if (-not (Test-Path $sourcePath)) {
    throw "Source icon not found: $sourcePath"
}

function Get-IconCropBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Threshold = 18
    )

    $background = $Bitmap.GetPixel(0, 0)
    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            $diff = [Math]::Max(
                [Math]::Abs($pixel.R - $background.R),
                [Math]::Max(
                    [Math]::Abs($pixel.G - $background.G),
                    [Math]::Abs($pixel.B - $background.B)
                )
            )

            if ($diff -gt $Threshold) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt 0 -or $maxY -lt 0) {
        throw 'Unable to detect icon bounds from source image.'
    }

    $width = $maxX - $minX + 1
    $height = $maxY - $minY + 1
    $size = [Math]::Max($width, $height)
    $centerX = ($minX + $maxX) / 2.0
    $centerY = ($minY + $maxY) / 2.0
    $left = [Math]::Floor($centerX - ($size / 2.0))
    $top = [Math]::Floor($centerY - ($size / 2.0))

    if ($left -lt 0) { $left = 0 }
    if ($top -lt 0) { $top = 0 }
    if (($left + $size) -gt $Bitmap.Width) { $left = $Bitmap.Width - $size }
    if (($top + $size) -gt $Bitmap.Height) { $top = $Bitmap.Height - $size }

    return [System.Drawing.Rectangle]::new([int]$left, [int]$top, [int]$size, [int]$size)
}

function Save-ResizedPng {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$Size,
        [string]$Destination
    )

    $canvas = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    $graphics.Dispose()

    $directory = Split-Path -Parent $Destination
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $canvas.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose()
}

$sourceBitmap = [System.Drawing.Bitmap]::FromFile($sourcePath)
$cropRect = Get-IconCropBounds -Bitmap $sourceBitmap
$croppedBitmap = $sourceBitmap.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

Save-ResizedPng -Source $croppedBitmap -Size 1024 -Destination $baseOutputPath

$androidTargets = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
    'android\app\src\main\res\mipmap-mdpi\ic_launcher_round.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher_round.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher_round.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher_round.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher_round.png' = 192
}

foreach ($target in $androidTargets.GetEnumerator()) {
    Save-ResizedPng -Source $croppedBitmap -Size $target.Value -Destination (Join-Path $projectRoot $target.Key)
}

$iosTargets = @{
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
}

foreach ($target in $iosTargets.GetEnumerator()) {
    Save-ResizedPng -Source $croppedBitmap -Size $target.Value -Destination (Join-Path $projectRoot $target.Key)
}

$croppedBitmap.Dispose()
$sourceBitmap.Dispose()

Write-Output "Generated app icons from $sourcePath"
