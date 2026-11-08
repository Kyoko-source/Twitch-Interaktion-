param([string]$Version='4.2.4')
$ErrorActionPreference='Stop'
$taskRepo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskProject=Join-Path $taskRepo 'games/kinderparadies'
$taskBuild=Join-Path $taskProject 'build'
$taskPlayer=Join-Path $taskBuild 'player-package'
$taskDownloads=Join-Path $taskRepo 'frontend/public/downloads'
if($Version -notmatch '^\d+\.\d+\.\d+$'){throw 'Invalid package version'}
foreach($taskRequired in @('windows/AfterPlay.exe')){
 if(-not (Test-Path -LiteralPath (Join-Path $taskBuild $taskRequired))){throw "Missing export: $taskRequired"}
}
# Only this generated output directory may be cleared. Reject junctions
# in the path or tree rather than following them into unrelated user files.
function Reset-PlayerOutput([string]$Path){
 $taskAbsolute=[IO.Path]::GetFullPath($Path)
 if($taskAbsolute -notin @($taskPlayer)){throw "Not a generated output: $taskAbsolute"}
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
foreach($taskSource in @('assets/horse-v420/provenance.json','assets/polyhaven-provenance.json','assets/ambience/provenance.json','assets/ambience-v180/provenance.json','assets/ambience-v193/provenance.json','assets/finale/provenance.json','assets/surfaces/provenance.json','assets/props/anatomy-provenance.json','assets/backstage-v270/provenance.json','assets/backstage-v270/Caveat-source.json','assets/revamp-v300/provenance.json','assets/wall-v383/wall-provenance.json','assets/party-v385/party-provenance.json','assets/quality-v410/audio-provenance.json')){
 Add-PublicSources (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $taskProject $taskSource) | ConvertFrom-Json)
}
[IO.File]::WriteAllText((Join-Path $taskLicenses 'Quellen.txt'),("AFTER PLAY - Quellen und Urheber"+[Environment]::NewLine+[Environment]::NewLine+(($taskSources | Sort-Object -Unique) -join [Environment]::NewLine)),[Text.UTF8Encoding]::new($false))
$taskZip=Join-Path $taskBuild "after-play-windows-v$Version.zip"
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $taskPlayer).FullName -DestinationPath $taskZip -Force
New-Item -ItemType Directory -Path $taskDownloads -Force | Out-Null
Copy-Item -LiteralPath $taskZip -Destination $taskDownloads -Force
foreach($taskMedia in @{'After-Play-Trailer-1080p.mp4'='after-play-trailer-1080p.mp4';'Happyland-Alter-Werbefilm.mp4'='after-play-happyland-werbefilm.mp4'}.GetEnumerator()){
 $taskMediaSource=Join-Path $taskBuild ('trailer/'+$taskMedia.Key)
 if(Test-Path -LiteralPath $taskMediaSource){Copy-Item -LiteralPath $taskMediaSource -Destination (Join-Path $taskDownloads $taskMedia.Value) -Force}
}
$taskManifest=[ordered]@{version=$Version;packaging_revision=3;engine='Godot 4.6.2';windows_sha256=(Get-FileHash $taskZip -Algorithm SHA256).Hash.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $taskBuild 'release.json'),($taskManifest | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output "Player packages ready: $taskZip"
& (Join-Path $PSScriptRoot 'prune-after-play-releases.ps1') -Apply
