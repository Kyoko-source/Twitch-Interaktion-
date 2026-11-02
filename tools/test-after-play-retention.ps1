$ErrorActionPreference='Stop'
$taskTempRoot=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('after-play-retention-'+[Guid]::NewGuid().ToString('N'))))
$taskBuild=Join-Path $taskTempRoot 'games/kinderparadies/build'
$taskDownloads=Join-Path $taskTempRoot 'frontend/public/downloads'
New-Item -ItemType Directory -Path $taskBuild,$taskDownloads -Force | Out-Null
$taskChecks=0
try{
 foreach($taskVersion in @('1.0.0','3.8.0','3.8.2','3.8.3','4.0.0')){
  foreach($taskPlatform in @('windows','web')){
   $taskName="after-play-$taskPlatform-v$taskVersion.zip"
   foreach($taskRoot in @($taskBuild,$taskDownloads)){[IO.File]::WriteAllText((Join-Path $taskRoot $taskName),$taskName)}
  }
  $taskStage=Join-Path $taskBuild "release-stage-v$taskVersion"
  New-Item -ItemType Directory -Path $taskStage | Out-Null
  [IO.File]::WriteAllText((Join-Path $taskStage 'fake.pck'),'fixture')
 }
 [IO.File]::WriteAllText((Join-Path $taskDownloads 'nachtwache-windows-v1.0.0.zip'),'legacy')
 [IO.File]::WriteAllText((Join-Path $taskDownloads 'personal.zip'),'personal')
 $taskManifest=[ordered]@{version='3.8.3';windows_sha256=(Get-FileHash -LiteralPath (Join-Path $taskBuild 'after-play-windows-v3.8.3.zip')).Hash.ToLowerInvariant();web_zip_sha256=(Get-FileHash -LiteralPath (Join-Path $taskBuild 'after-play-web-v3.8.3.zip')).Hash.ToLowerInvariant()}
 $taskManifestPath=Join-Path $taskBuild 'release.json'
 [IO.File]::WriteAllText($taskManifestPath,($taskManifest | ConvertTo-Json))
 $taskPruner=Join-Path $PSScriptRoot 'prune-after-play-releases.ps1'
 $taskPlan=(& $taskPruner -RepoPath $taskTempRoot) | ConvertFrom-Json
 if($taskPlan.RemoveCount -ne 11 -or $taskPlan.Keep -notcontains '3.8.2'){throw 'Incorrect dry run plan'}
 if(-not (Test-Path -LiteralPath (Join-Path $taskBuild 'after-play-windows-v1.0.0.zip'))){throw 'Dry run deleted files'}
 $taskChecks+=2
 # A damaged current package must stop cleanup before touching older versions.
 [IO.File]::AppendAllText((Join-Path $taskDownloads 'after-play-web-v3.8.3.zip'),'damaged')
 $taskRefused=$false
 try{& $taskPruner -RepoPath $taskTempRoot -Apply | Out-Null}catch{$taskRefused=$true}
 if(-not $taskRefused -or -not (Test-Path -LiteralPath (Join-Path $taskBuild 'after-play-windows-v1.0.0.zip'))){throw 'Unsafe checksum failure behavior'}
 $taskChecks++
 Copy-Item -LiteralPath (Join-Path $taskBuild 'after-play-web-v3.8.3.zip') -Destination $taskDownloads -Force
 & $taskPruner -RepoPath $taskTempRoot -Apply | Out-Null
 foreach($taskVersion in @('3.8.2','3.8.3','4.0.0')){
  if(-not (Test-Path -LiteralPath (Join-Path $taskBuild "after-play-windows-v$taskVersion.zip"))){throw 'Kept or future release was deleted'}
  $taskChecks++
 }
 if((Test-Path -LiteralPath (Join-Path $taskBuild 'release-stage-v3.8.0')) -or (Test-Path -LiteralPath (Join-Path $taskDownloads 'nachtwache-windows-v1.0.0.zip'))){throw 'Old generated outputs remain'}
 if(-not (Test-Path -LiteralPath (Join-Path $taskDownloads 'personal.zip'))){throw 'Unrelated file deleted'}
 $taskChecks+=2
 Write-Output "Local retention: $taskChecks checks PASS"
}finally{
 if($taskTempRoot.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $taskTempRoot) -match '^after-play-retention-[a-f0-9]{32}$'){
  Remove-Item -LiteralPath $taskTempRoot -Recurse -Force
 }
}
