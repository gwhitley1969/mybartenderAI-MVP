# PowerShell script to create a martini glass icon with background
Add-Type -AssemblyName System.Drawing

$width = 512
$height = 512

# Create a new bitmap
$bitmap = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

# Set high quality rendering
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Fill background with dark blue-gray color from the app theme
$backgroundColor = [System.Drawing.Color]::FromArgb(255, 28, 28, 46)  # #1C1C2E
$graphics.Clear($backgroundColor)

# Add a subtle circular background for the icon
$circleColor = [System.Drawing.Color]::FromArgb(255, 40, 40, 58)  # Slightly lighter
$circleBrush = New-Object System.Drawing.SolidBrush($circleColor)
$graphics.FillEllipse($circleBrush, 56, 56, 400, 400)

# Define colors for the martini glass
$iconColor = [System.Drawing.Color]::FromArgb(255, 100, 188, 236)  # #64BCEC - matches home screen
$fillColor = [System.Drawing.Color]::FromArgb(100, 100, 188, 236)   # Semi-transparent fill
$oliveColor = [System.Drawing.Color]::FromArgb(255, 143, 209, 79)  # #8FD14F
$pimentoColor = [System.Drawing.Color]::FromArgb(255, 210, 48, 44) # #D2302C

# Create pens and brushes with thicker lines for visibility
$pen = New-Object System.Drawing.Pen($iconColor, 20)  # Thicker line
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$fillBrush = New-Object System.Drawing.SolidBrush($fillColor)
$iconBrush = New-Object System.Drawing.SolidBrush($iconColor)
$oliveBrush = New-Object System.Drawing.SolidBrush($oliveColor)
$pimentoBrush = New-Object System.Drawing.SolidBrush($pimentoColor)

# Center and scale the martini glass
$centerX = 256
$centerY = 256

# Draw the martini glass - V shape
# Top of glass
$graphics.DrawLine($pen, 156, 156, 256, 300)  # Left side of V
$graphics.DrawLine($pen, 356, 156, 256, 300)  # Right side of V
$graphics.DrawLine($pen, 156, 156, 356, 156)  # Top rim

# Fill the glass with "liquid"
$liquidPoints = @(
    (New-Object System.Drawing.Point(176, 176)),
    (New-Object System.Drawing.Point(256, 280)),
    (New-Object System.Drawing.Point(336, 176))
)
$graphics.FillPolygon($fillBrush, $liquidPoints)

# Stem
$graphics.DrawLine($pen, 256, 300, 256, 380)

# Base
$graphics.DrawLine($pen, 206, 380, 306, 380)

# Olive with toothpick
# Draw toothpick first (behind olive)
$toothpickPen = New-Object System.Drawing.Pen($iconColor, 6)
$graphics.DrawLine($toothpickPen, 200, 180, 240, 220)

# Draw olive
$graphics.FillEllipse($oliveBrush, 185, 165, 30, 30)
# Pimento center
$graphics.FillEllipse($pimentoBrush, 194, 174, 12, 12)

# Save the main icon
$iconPath = "C:\backup dev02\mybartenderAI-MVP\mobile\app\assets\icon\icon.png"
$bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Create a foreground version for adaptive icon (no background)
$bitmapForeground = New-Object System.Drawing.Bitmap($width, $height)
$graphicsForeground = [System.Drawing.Graphics]::FromImage($bitmapForeground)
$graphicsForeground.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphicsForeground.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphicsForeground.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Clear to transparent
$graphicsForeground.Clear([System.Drawing.Color]::Transparent)

# Draw the same martini glass on transparent background
$graphicsForeground.DrawLine($pen, 156, 156, 256, 300)
$graphicsForeground.DrawLine($pen, 356, 156, 256, 300)
$graphicsForeground.DrawLine($pen, 156, 156, 356, 156)
$graphicsForeground.FillPolygon($fillBrush, $liquidPoints)
$graphicsForeground.DrawLine($pen, 256, 300, 256, 380)
$graphicsForeground.DrawLine($pen, 206, 380, 306, 380)
$graphicsForeground.DrawLine($toothpickPen, 200, 180, 240, 220)
$graphicsForeground.FillEllipse($oliveBrush, 185, 165, 30, 30)
$graphicsForeground.FillEllipse($pimentoBrush, 194, 174, 12, 12)

$foregroundPath = "C:\backup dev02\mybartenderAI-MVP\mobile\app\assets\icon\icon_foreground.png"
$bitmapForeground.Save($foregroundPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up
$graphics.Dispose()
$graphicsForeground.Dispose()
$bitmap.Dispose()
$bitmapForeground.Dispose()
$pen.Dispose()
$toothpickPen.Dispose()
$fillBrush.Dispose()
$iconBrush.Dispose()
$oliveBrush.Dispose()
$pimentoBrush.Dispose()
$circleBrush.Dispose()

Write-Host "Icons created successfully:"
Write-Host "  - $iconPath"
Write-Host "  - $foregroundPath"