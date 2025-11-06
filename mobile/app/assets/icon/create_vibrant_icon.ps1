# PowerShell script to create a vibrant martini glass icon with bright magenta background
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

# VIBRANT MAGENTA BACKGROUND - Very bright and clearly visible
$backgroundColor = [System.Drawing.Color]::FromArgb(255, 255, 0, 255)  # Pure Magenta (FF00FF)
$graphics.Clear($backgroundColor)

# Define colors for the martini glass - use WHITE for maximum contrast
$glassColor = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)     # Pure white
$fillColor = [System.Drawing.Color]::FromArgb(180, 200, 200, 255)      # Light blue-ish with transparency
$oliveColor = [System.Drawing.Color]::FromArgb(255, 143, 209, 79)      # Green olive
$pimentoColor = [System.Drawing.Color]::FromArgb(255, 255, 0, 0)       # Red pimento

# Create pens and brushes with thick lines for visibility
$pen = New-Object System.Drawing.Pen($glassColor, 24)
$pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$fillBrush = New-Object System.Drawing.SolidBrush($fillColor)
$glassBrush = New-Object System.Drawing.SolidBrush($glassColor)
$oliveBrush = New-Object System.Drawing.SolidBrush($oliveColor)
$pimentoBrush = New-Object System.Drawing.SolidBrush($pimentoColor)

# Center and scale the martini glass - make it bigger and more centered
$centerX = 256
$centerY = 256

# Draw the martini glass - V shape (larger and more prominent)
# Top of glass
$graphics.DrawLine($pen, 130, 140, 256, 310)  # Left side of V
$graphics.DrawLine($pen, 382, 140, 256, 310)  # Right side of V
$graphics.DrawLine($pen, 130, 140, 382, 140)  # Top rim

# Fill the glass with "liquid"
$liquidPoints = @(
    (New-Object System.Drawing.Point(154, 160)),
    (New-Object System.Drawing.Point(256, 290)),
    (New-Object System.Drawing.Point(358, 160))
)
$graphics.FillPolygon($fillBrush, $liquidPoints)

# Stem (longer and more visible)
$graphics.DrawLine($pen, 256, 310, 256, 400)

# Base (wider)
$graphics.DrawLine($pen, 190, 400, 322, 400)

# Olive with toothpick
# Draw toothpick first (behind olive) - thicker
$toothpickPen = New-Object System.Drawing.Pen($glassColor, 8)
$graphics.DrawLine($toothpickPen, 180, 170, 230, 210)

# Draw olive (larger)
$graphics.FillEllipse($oliveBrush, 165, 155, 40, 40)
# Pimento center (larger)
$graphics.FillEllipse($pimentoBrush, 177, 167, 16, 16)

# Save the main icon
$iconPath = "C:\backup dev02\mybartenderAI-MVP\mobile\app\assets\icon\icon.png"
$bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Create a foreground version for adaptive icon (transparent background)
$bitmapForeground = New-Object System.Drawing.Bitmap($width, $height)
$graphicsForeground = [System.Drawing.Graphics]::FromImage($bitmapForeground)
$graphicsForeground.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphicsForeground.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphicsForeground.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Clear to transparent
$graphicsForeground.Clear([System.Drawing.Color]::Transparent)

# For the foreground, use a colored glass (not white) since it will be on various backgrounds
$fgGlassColor = [System.Drawing.Color]::FromArgb(255, 100, 188, 236)  # Blue
$fgPen = New-Object System.Drawing.Pen($fgGlassColor, 24)
$fgPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$fgPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$fgToothpickPen = New-Object System.Drawing.Pen($fgGlassColor, 8)

# Draw the same martini glass on transparent background
$graphicsForeground.DrawLine($fgPen, 130, 140, 256, 310)
$graphicsForeground.DrawLine($fgPen, 382, 140, 256, 310)
$graphicsForeground.DrawLine($fgPen, 130, 140, 382, 140)
$graphicsForeground.FillPolygon($fillBrush, $liquidPoints)
$graphicsForeground.DrawLine($fgPen, 256, 310, 256, 400)
$graphicsForeground.DrawLine($fgPen, 190, 400, 322, 400)
$graphicsForeground.DrawLine($fgToothpickPen, 180, 170, 230, 210)
$graphicsForeground.FillEllipse($oliveBrush, 165, 155, 40, 40)
$graphicsForeground.FillEllipse($pimentoBrush, 177, 167, 16, 16)

$foregroundPath = "C:\backup dev02\mybartenderAI-MVP\mobile\app\assets\icon\icon_foreground.png"
$bitmapForeground.Save($foregroundPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up
$graphics.Dispose()
$graphicsForeground.Dispose()
$bitmap.Dispose()
$bitmapForeground.Dispose()
$pen.Dispose()
$fgPen.Dispose()
$toothpickPen.Dispose()
$fgToothpickPen.Dispose()
$fillBrush.Dispose()
$glassBrush.Dispose()
$oliveBrush.Dispose()
$pimentoBrush.Dispose()

Write-Host "Vibrant magenta icons created successfully:"
Write-Host "  - $iconPath"
Write-Host "  - $foregroundPath"
Write-Host ""
Write-Host "Background color: Pure Magenta (FF00FF)"
Write-Host "Glass color: White for maximum contrast"
