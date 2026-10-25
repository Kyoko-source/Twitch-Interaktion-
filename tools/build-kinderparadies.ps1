param([switch]$WithQA)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$taskRepo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskProject=Join-Path $taskRepo 'games/kinderparadies'
$taskTools=Join-Path $PSScriptRoot 'godot-portable'
$taskGodot=Join-Path $taskTools 'Godot_v4.6.2-stable_win64_console.exe'
function Invoke-NachtwacheEngine([string[]]$EngineArgs){
 # Godot can print a runtime script error yet return exit code zero. Such a
 # build must never be packaged merely because the assertion runner finished.
 $taskPreviousPreference=$ErrorActionPreference
 $ErrorActionPreference='Continue'
 $taskEngineOutput=@(& $taskGodot @EngineArgs 2>&1 | ForEach-Object {$_.ToString()})
 $taskEngineExit=$LASTEXITCODE
 $ErrorActionPreference=$taskPreviousPreference
 $taskEngineOutput | Write-Output
 if($taskEngineExit -ne 0 -or ($taskEngineOutput -match 'SCRIPT ERROR:|ERROR:').Count -gt 0){throw 'Godot failed or reported a script/runtime error.'}
}
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
[IO.File]::WriteAllText((Join-Path $taskProject 'build/.gdignore'),'',[Text.UTF8Encoding]::new($false))
$taskChief=Join-Path $taskRepo 'NACHTWACHE INTRO/chef.mp3'
if(Test-Path -LiteralPath $taskChief){Copy-Item -LiteralPath $taskChief -Destination (Join-Path $taskProject 'assets/intro/chef.mp3') -Force}
$taskMusicBox=Join-Path $taskRepo 'NACHTWACHE MUSIKBOX/Musikbox.mp3'
if(-not (Test-Path -LiteralPath $taskMusicBox)){throw 'Put Musikbox.mp3 in NACHTWACHE MUSIKBOX before building the game.'}
Copy-Item -LiteralPath $taskMusicBox -Destination (Join-Path $taskProject 'assets/party/musicbox.mp3') -Force
$taskMenuSong=Join-Path $taskRepo 'AFTER PLAY MENUMUSIK/Abandoned Arcade.mp3'
if(-not (Test-Path -LiteralPath $taskMenuSong)){throw 'Put Abandoned Arcade.mp3 in AFTER PLAY MENUMUSIK before building the game.'}
Copy-Item -LiteralPath $taskMenuSong -Destination (Join-Path $taskProject 'assets/menu/abandoned-arcade.mp3') -Force
Invoke-NachtwacheEngine -EngineArgs @('--headless','--path',$taskProject,'--editor','--import','--quit')
Invoke-NachtwacheEngine -EngineArgs @('--headless','--path',$taskProject,'--','--self-test')
$taskExports=@('Windows','Web')
if($WithQA){$taskExports+='Web QA'}
foreach($taskPreset in $taskExports){
 Invoke-NachtwacheEngine -EngineArgs @('--headless','--path',$taskProject,'--export-release',$taskPreset)
}
foreach($taskTarget in @('build/qa')){
 $taskHtml=Join-Path $taskProject ($taskTarget+'/index.html')
 if(Test-Path -LiteralPath $taskHtml){
  $taskText=[IO.File]::ReadAllText($taskHtml).Replace('<html lang="en">','<html lang="de">').Replace('<head>','<head>'+[Environment]::NewLine+'<link rel="icon" href="data:,">').Replace('<canvas id="canvas">','<canvas id="canvas" role="application" aria-label="After Play 3D-Spiel" tabindex="0">').Replace('Your browser does not support the canvas tag.','Dein Browser kann dieses 3D-Spiel nicht anzeigen. Nutze die Windows-Fassung.').Replace('Your browser does not support JavaScript.','Bitte aktiviere JavaScript oder nutze die Windows-Fassung.')
  [IO.File]::WriteAllText($taskHtml,$taskText,[Text.UTF8Encoding]::new($false))
 }
}
& (Join-Path $PSScriptRoot 'package-kinderparadies.ps1')
