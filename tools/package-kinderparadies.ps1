param([string]$Version='2.9.0')
$ErrorActionPreference='Stop'
$taskRepo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskProject=Join-Path $taskRepo 'games/kinderparadies'
$taskBuild=Join-Path $taskProject 'build'
$taskPlayer=Join-Path $taskBuild 'player-package'
$taskBrowser=Join-Path $taskBuild 'browser-package'
$taskPublic=Join-Path $taskRepo 'frontend/public/standalone/kinderparadies'
$taskDownloads=Join-Path $taskRepo 'frontend/public/downloads'
if($Version -notmatch '^\d+\.\d+\.\d+$'){throw 'Invalid package version'}
foreach($taskRequired in @('windows/AfterPlay.exe','web/index.html','web/index.js','web/index.wasm','web/index.pck','web/index.audio.worklet.js','web/index.audio.position.worklet.js')){
 if(-not (Test-Path -LiteralPath (Join-Path $taskBuild $taskRequired))){throw "Missing export: $taskRequired"}
}
# Only these three generated output directories may be cleared. Reject junctions
# in the path or tree rather than following them into unrelated user files.
function Reset-PlayerOutput([string]$Path){
 $taskAbsolute=[IO.Path]::GetFullPath($Path)
 if($taskAbsolute -notin @($taskPlayer,$taskBrowser,$taskPublic)){throw "Not a generated output: $taskAbsolute"}
 $taskAncestor=$taskAbsolute
 while($taskAncestor -and $taskAncestor -ne $taskRepo){
  if(Test-Path -LiteralPath $taskAncestor){
   if((Get-Item -LiteralPath $taskAncestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked output path: $taskAncestor"}
  }
  $taskAncestor=Split-Path -Parent $taskAncestor
 }
 if($taskAncestor -ne $taskRepo){throw 'Output escaped repository'}
 if(Test-Path -LiteralPath $taskAbsolute){
  if(Get-ChildItem -LiteralPath $taskAbsolute -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}){throw 'Linked entry in generated output'}
  Remove-Item -LiteralPath $taskAbsolute -Recurse -Force
 }
 New-Item -ItemType Directory -Path $taskAbsolute -Force | Out-Null
}
Reset-PlayerOutput $taskPlayer
Reset-PlayerOutput $taskBrowser
Copy-Item -LiteralPath (Join-Path $taskBuild 'windows/AfterPlay.exe') -Destination $taskPlayer
Copy-Item -LiteralPath (Join-Path $taskProject 'distribution/STARTEN.txt') -Destination $taskPlayer
$taskLicenses=Join-Path $taskPlayer 'Lizenzen'
New-Item -ItemType Directory -Path $taskLicenses | Out-Null
Copy-Item -LiteralPath (Join-Path $taskProject 'distribution/Lizenzhinweise.txt') -Destination $taskLicenses
$taskNotices=[ordered]@{
 'assets/Kenney-Impact-License.txt'='Kenney.txt'
 'assets/Oswald-OFL.txt'='Oswald-OFL.txt'
 'assets/presentation-v250/BodoniModa-OFL.txt'='BodoniModa-OFL.txt'
 'assets/backstage-v270/Caveat-OFL.txt'='Caveat-OFL.txt'
 'assets/props/Head-Attribution.txt'='Lee-Perry-Smith.txt'
}
foreach($taskSource in $taskNotices.Keys){Copy-Item -LiteralPath (Join-Path $taskProject $taskSource) -Destination (Join-Path $taskLicenses $taskNotices[$taskSource])}
foreach($taskFile in @('LICENSE.txt','COPYRIGHT.txt')){
 # The original engine notices are cached privately, not beside the player EXE.
 $taskCached=Join-Path $taskBuild ('package/Godot-'+$taskFile)
 if(-not (Test-Path -LiteralPath $taskCached)){
  New-Item -ItemType Directory -Path (Split-Path $taskCached) -Force | Out-Null
  Invoke-WebRequest -UseBasicParsing -Uri ('https://raw.githubusercontent.com/godotengine/godot/4.6.2-stable/'+$taskFile) -OutFile $taskCached
 }
 Copy-Item -LiteralPath $taskCached -Destination $taskLicenses
}
# Preserve public source/author/license credits, but omit prompts, local paths,
# hashes, processing commands and story image names from developer manifests.
$taskSources=[Collections.Generic.List[string]]::new()
function Add-PublicSources($Value){
 if($null -eq $Value){return}
 if($Value -is [Array]){foreach($taskEntry in $Value){Add-PublicSources $taskEntry};return}
 if($Value -isnot [PSCustomObject]){return}
 $taskUrls=@($Value.PSObject.Properties | Where-Object {$_.Name -in @('source','url') -and $_.Value -is [string] -and $_.Value -match '^https?://'} | ForEach-Object {$_.Value})
 foreach($taskUrl in $taskUrls){
  $taskCredit=@($Value.author,$Value.license,$taskUrl) | Where-Object {$_ -is [string] -and $_}
  $taskSources.Add(($taskCredit -join ' | '))
 }
 foreach($taskProperty in $Value.PSObject.Properties){Add-PublicSources $taskProperty.Value}
}
foreach($taskSource in @('assets/polyhaven-provenance.json','assets/ambience/provenance.json','assets/ambience-v180/provenance.json','assets/ambience-v193/provenance.json','assets/finale/provenance.json','assets/surfaces/provenance.json','assets/props/anatomy-provenance.json','assets/backstage-v270/provenance.json','assets/backstage-v270/Caveat-source.json')){
 Add-PublicSources (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $taskProject $taskSource) | ConvertFrom-Json)
}
[IO.File]::WriteAllText((Join-Path $taskLicenses 'Quellen.txt'),("AFTER PLAY - Quellen und Urheber"+[Environment]::NewLine+[Environment]::NewLine+(($taskSources | Sort-Object -Unique) -join [Environment]::NewLine)),[Text.UTF8Encoding]::new($false))
$taskRuntime=@('index.html','index.js','index.wasm','index.pck','index.audio.worklet.js','index.audio.position.worklet.js')
foreach($taskFile in $taskRuntime){Copy-Item -LiteralPath (Join-Path $taskBuild ('web/'+$taskFile)) -Destination $taskBrowser}
$taskHtml=Join-Path $taskBrowser 'index.html'
$taskText=[IO.File]::ReadAllText($taskHtml).Replace('<html lang="en">','<html lang="de">').Replace('<canvas id="canvas">','<canvas id="canvas" role="application" aria-label="After Play 3D-Spiel" tabindex="0">').Replace('Your browser does not support the canvas tag.','Dein Browser kann dieses 3D-Spiel nicht anzeigen. Nutze die Windows-Fassung.').Replace('Your browser does not support JavaScript.','Bitte aktiviere JavaScript oder nutze die Windows-Fassung.')
if(-not $taskText.Contains('href="data:,"')){$taskText=$taskText.Replace('<head>','<head>'+[Environment]::NewLine+'<link rel="icon" href="data:,">')}
[IO.File]::WriteAllText($taskHtml,$taskText,[Text.UTF8Encoding]::new($false))
if(Test-Path -LiteralPath (Join-Path $taskBuild 'web/index.png')){Copy-Item -LiteralPath (Join-Path $taskBuild 'web/index.png') -Destination $taskBrowser}
Copy-Item -LiteralPath $taskLicenses -Destination $taskBrowser -Recurse
$taskZip=Join-Path $taskBuild "after-play-windows-v$Version.zip"
$taskWebZip=Join-Path $taskBuild "after-play-web-v$Version.zip"
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $taskPlayer).FullName -DestinationPath $taskZip -Force
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $taskBrowser).FullName -DestinationPath $taskWebZip -Force
Reset-PlayerOutput $taskPublic
Copy-Item -LiteralPath (Get-ChildItem -LiteralPath $taskBrowser).FullName -Destination $taskPublic -Recurse
New-Item -ItemType Directory -Path $taskDownloads -Force | Out-Null
Copy-Item -LiteralPath $taskZip,$taskWebZip -Destination $taskDownloads -Force
$taskManifest=[ordered]@{version=$Version;packaging_revision=2;engine='Godot 4.6.2';windows_sha256=(Get-FileHash $taskZip -Algorithm SHA256).Hash.ToLowerInvariant();web_zip_sha256=(Get-FileHash $taskWebZip -Algorithm SHA256).Hash.ToLowerInvariant();web_pck_sha256=(Get-FileHash (Join-Path $taskBrowser 'index.pck') -Algorithm SHA256).Hash.ToLowerInvariant();web_wasm_sha256=(Get-FileHash (Join-Path $taskBrowser 'index.wasm') -Algorithm SHA256).Hash.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $taskBuild 'release.json'),($taskManifest | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output "Player packages ready: $taskZip"
