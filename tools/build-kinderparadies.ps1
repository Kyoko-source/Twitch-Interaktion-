param([switch]$WithQA)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$taskRepo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskProject=Join-Path $taskRepo 'games/kinderparadies'
$taskTools=Join-Path $PSScriptRoot 'godot-portable'
$taskGodot=Join-Path $taskTools 'Godot_v4.6.2-stable_win64_console.exe'
if(-not (Test-Path -LiteralPath $taskGodot)){
 New-Item -ItemType Directory -Force -Path $taskTools | Out-Null
 $taskBase='https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/'
 Invoke-WebRequest -UseBasicParsing -Uri ($taskBase+'Godot_v4.6.2-stable_win64.exe.zip') -OutFile (Join-Path $taskTools 'godot.zip')
 Invoke-WebRequest -UseBasicParsing -Uri ($taskBase+'SHA512-SUMS.txt') -OutFile (Join-Path $taskTools 'SHA512-SUMS.txt')
 $taskExpected=(Get-Content (Join-Path $taskTools 'SHA512-SUMS.txt') | Where-Object {$_ -match 'Godot_v4.6.2-stable_win64.exe.zip$'}).Split(' ')[0]
 if((Get-FileHash (Join-Path $taskTools 'godot.zip') -Algorithm SHA512).Hash.ToLowerInvariant() -ne $taskExpected){throw 'Godot SHA512 mismatch'}
 Expand-Archive -LiteralPath (Join-Path $taskTools 'godot.zip') -DestinationPath $taskTools -Force
}
if(-not (Test-Path -LiteralPath (Join-Path $taskTools 'templates/web_nothreads_release.zip')) -or -not (Test-Path -LiteralPath (Join-Path $taskTools 'templates/windows_release_x86_64.exe'))){
 $taskPython=Join-Path $env:LOCALAPPDATA 'Python/bin/python.exe'
 if(-not (Test-Path -LiteralPath $taskPython)){throw 'Python is required once to fetch selected export templates.'}
 & $taskPython (Join-Path $PSScriptRoot 'prepare-kinderparadies-templates.py')
 if($LASTEXITCODE -ne 0){throw 'Template download failed'}
}
foreach($taskDir in @('build/windows','build/web','build/qa','build/package')){New-Item -ItemType Directory -Force -Path (Join-Path $taskProject $taskDir) | Out-Null}
& $taskGodot --headless --path $taskProject --editor --import --quit
if($LASTEXITCODE -ne 0){throw 'Godot import failed'}
& $taskGodot --headless --path $taskProject -- --self-test
if($LASTEXITCODE -ne 0){throw 'Game validation failed'}
$taskExports=@('Windows','Web')
if($WithQA){$taskExports+='Web QA'}
foreach($taskPreset in $taskExports){
 & $taskGodot --headless --path $taskProject --export-release $taskPreset
 if($LASTEXITCODE -ne 0){throw "Export failed: $taskPreset"}
}
foreach($taskTarget in @('build/web','build/qa')){
 $taskHtml=Join-Path $taskProject ($taskTarget+'/index.html')
 if(Test-Path -LiteralPath $taskHtml){
  $taskText=[IO.File]::ReadAllText($taskHtml).Replace('<html lang="en">','<html lang="de">').Replace('<head>','<head>'+[Environment]::NewLine+'<link rel="icon" href="data:,">').Replace('<canvas id="canvas">','<canvas id="canvas" role="application" aria-label="NACHTWACHE 3D-Spiel" tabindex="0">').Replace('Your browser does not support the canvas tag.','Dein Browser kann dieses 3D-Spiel nicht anzeigen. Nutze die Windows-Fassung.').Replace('Your browser does not support JavaScript.','Bitte aktiviere JavaScript oder nutze die Windows-Fassung.')
  [IO.File]::WriteAllText($taskHtml,$taskText,[Text.UTF8Encoding]::new($false))
 }
}
$taskPackage=Join-Path $taskProject 'build/package'
Copy-Item -LiteralPath (Join-Path $taskProject 'build/windows/Nachtwache.exe') -Destination $taskPackage -Force
Copy-Item -LiteralPath (Join-Path $taskProject 'README.md') -Destination (Join-Path $taskPackage 'LIESMICH.md') -Force
Copy-Item -LiteralPath (Join-Path $taskProject 'assets/Kenney-Impact-License.txt'),(Join-Path $taskProject 'assets/Oswald-OFL.txt') -Destination $taskPackage -Force
foreach($taskFile in @('LICENSE.txt','COPYRIGHT.txt')){
 $taskLicense=Join-Path $taskPackage ('Godot-'+$taskFile)
 if(-not (Test-Path -LiteralPath $taskLicense)){Invoke-WebRequest -UseBasicParsing -Uri ('https://raw.githubusercontent.com/godotengine/godot/4.6.2-stable/'+$taskFile) -OutFile $taskLicense}
}
$taskZip=Join-Path $taskProject 'build/nachtwache-windows-v1.0.0.zip'
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $taskPackage -File | Select-Object -ExpandProperty FullName) -DestinationPath $taskZip -Force
$taskWeb=Join-Path $taskRepo 'frontend/public/standalone/kinderparadies'
$taskDownloads=Join-Path $taskRepo 'frontend/public/downloads'
New-Item -ItemType Directory -Force -Path $taskWeb,$taskDownloads | Out-Null
Copy-Item -Path (Join-Path $taskProject 'build/web/*') -Destination $taskWeb -Force
Copy-Item -LiteralPath $taskZip -Destination $taskDownloads -Force
$taskManifest=[ordered]@{version='1.0.0';engine='Godot 4.6.2';windows_sha256=(Get-FileHash $taskZip -Algorithm SHA256).Hash.ToLowerInvariant();web_pck_sha256=(Get-FileHash (Join-Path $taskWeb 'index.pck') -Algorithm SHA256).Hash.ToLowerInvariant();web_wasm_sha256=(Get-FileHash (Join-Path $taskWeb 'index.wasm') -Algorithm SHA256).Hash.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $taskProject 'build/release.json'),($taskManifest | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output "Built native Windows and Web releases: $taskZip"
