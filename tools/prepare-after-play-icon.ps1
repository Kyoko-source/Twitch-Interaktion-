# Format conversion only: retain the generated PNG master and create a Windows
# ICO containing real sizes, including a transparent margin for desktop use.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskIconRoot=Join-Path $taskRoot 'games/kinderparadies/assets/branding-v386'
$taskSource=[Drawing.Image]::FromFile((Join-Path $taskIconRoot 'after-play-icon.png'))
$taskEntries=@()
try {
 foreach($taskSize in @(16,24,32,48,64,128,256)) {
  $taskBitmap=New-Object Drawing.Bitmap($taskSize,$taskSize,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $taskGraphics=[Drawing.Graphics]::FromImage($taskBitmap)
  $taskStream=New-Object IO.MemoryStream
  try {
   $taskGraphics.Clear([Drawing.Color]::Transparent)
   $taskGraphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
   $taskGraphics.CompositingQuality=[Drawing.Drawing2D.CompositingQuality]::HighQuality
   $taskInset=[Math]::Max(1,[int]($taskSize*.06))
   $taskGraphics.DrawImage($taskSource,$taskInset,$taskInset,$taskSize-2*$taskInset,$taskSize-2*$taskInset)
   $taskBitmap.Save($taskStream,[Drawing.Imaging.ImageFormat]::Png)
   $taskEntries+=@{size=$taskSize;data=$taskStream.ToArray()}
  } finally {$taskStream.Dispose();$taskGraphics.Dispose();$taskBitmap.Dispose()}
 }
} finally {$taskSource.Dispose()}
$taskOutput=[IO.File]::Create((Join-Path $taskIconRoot 'after-play-icon.ico'))
$taskWriter=New-Object IO.BinaryWriter($taskOutput)
try {
 $taskWriter.Write([uint16]0);$taskWriter.Write([uint16]1);$taskWriter.Write([uint16]$taskEntries.Count)
 $taskOffset=6+16*$taskEntries.Count
 foreach($taskEntry in $taskEntries) {
  $taskDimension=if($taskEntry.size -eq 256){0}else{$taskEntry.size}
  $taskWriter.Write([byte]$taskDimension);$taskWriter.Write([byte]$taskDimension)
  $taskWriter.Write([byte]0);$taskWriter.Write([byte]0);$taskWriter.Write([uint16]1);$taskWriter.Write([uint16]32)
  $taskWriter.Write([uint32]$taskEntry.data.Length);$taskWriter.Write([uint32]$taskOffset)
  $taskOffset+=$taskEntry.data.Length
 }
 foreach($taskEntry in $taskEntries){$taskWriter.Write([byte[]]$taskEntry.data)}
} finally {$taskWriter.Dispose();$taskOutput.Dispose()}
Write-Output 'After Play ICO: 16, 24, 32, 48, 64, 128, 256 px; PNG master preserved.'
