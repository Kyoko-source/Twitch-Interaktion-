param([switch]$Apply,[string]$RepoPath=(Join-Path $PSScriptRoot '..'))
$ErrorActionPreference='Stop'
$taskRepo=(Resolve-Path -LiteralPath $RepoPath).Path
$taskBuild=Join-Path $taskRepo 'games/kinderparadies/build'
$taskDownloads=Join-Path $taskRepo 'frontend/public/downloads'
$taskManifest=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $taskBuild 'release.json') | ConvertFrom-Json
if($taskManifest.version -notmatch '^\d+\.\d+\.\d+$'){throw 'Invalid release version'}
$taskCurrent=[version]$taskManifest.version
$taskRoots=@($taskBuild,$taskDownloads)
function Assert-GeneratedPath([string]$Path,[string]$Parent){
 $taskAbsolute=[IO.Path]::GetFullPath($Path)
 if((Split-Path -Parent $taskAbsolute) -ne $Parent){throw "Not an immediate generated output: $taskAbsolute"}
 $taskAncestor=$taskAbsolute
 while($taskAncestor -and $taskAncestor -ne $taskRepo){
  if((Get-Item -LiteralPath $taskAncestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Linked output path: $taskAncestor"}
  $taskAncestor=Split-Path -Parent $taskAncestor
 }
 if($taskAncestor -ne $taskRepo){throw 'Output escaped repository'}
 if((Get-Item -LiteralPath $taskAbsolute).PSIsContainer){
  if(Get-ChildItem -LiteralPath $taskAbsolute -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}){throw "Linked entry in output: $taskAbsolute"}
 }
 return $taskAbsolute
}
# Confirm the new release exists in both locations before pruning any predecessor.
foreach($taskRoot in $taskRoots){
 foreach($taskPlatform in @('windows','web')){
  $taskArchive=Join-Path $taskRoot "after-play-$taskPlatform-v$taskCurrent.zip"
  Assert-GeneratedPath $taskArchive $taskRoot | Out-Null
  $taskExpected=if($taskPlatform -eq 'windows'){$taskManifest.windows_sha256}else{$taskManifest.web_zip_sha256}
  if((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskExpected){throw "Current archive checksum mismatch: $taskArchive"}
 }
}
$taskArchives=@(foreach($taskFile in Get-ChildItem -LiteralPath $taskBuild -File){
 if($taskFile.Name -match '^after-play-(windows|web)-v(\d+\.\d+\.\d+)\.zip$'){
  [PSCustomObject]@{Version=[version]$Matches[2];Platform=$Matches[1]}
 }
})
$taskPrevious=$taskArchives | Group-Object Version | Where-Object {([version]$_.Name) -lt $taskCurrent -and ($_.Group.Platform | Sort-Object -Unique).Count -eq 2} | Sort-Object {[version]$_.Name} -Descending | Select-Object -First 1
$taskKeep=@([string]$taskCurrent)
if($taskPrevious){$taskKeep+=([string]$taskPrevious.Name)}
$taskRemove=@(foreach($taskRoot in $taskRoots){
 foreach($taskItem in Get-ChildItem -LiteralPath $taskRoot){
  $taskVersion=$null
  if(-not $taskItem.PSIsContainer -and $taskItem.Name -match '^(after-play|nachtwache|kinderparadies)-(windows|web)-v(\d+\.\d+\.\d+)\.zip$'){$taskVersion=[version]$Matches[3]}
  if($taskRoot -eq $taskBuild -and $taskItem.PSIsContainer -and $taskItem.Name -match '^release-stage-v(\d+\.\d+\.\d+)(-[a-f0-9]{32})?$'){$taskVersion=[version]$Matches[1]}
  if($null -ne $taskVersion -and $taskVersion -le $taskCurrent -and ([string]$taskVersion) -notin $taskKeep){
   $taskTarget=Assert-GeneratedPath $taskItem.FullName $taskRoot
   $taskBytes=if($taskItem.PSIsContainer){(Get-ChildItem -LiteralPath $taskTarget -Recurse -File | Measure-Object Length -Sum).Sum}else{$taskItem.Length}
   [PSCustomObject]@{Path=$taskTarget;Parent=$taskRoot;Bytes=[long]$taskBytes}
  }
 }
})
[PSCustomObject]@{Apply=[bool]$Apply;Keep=$taskKeep;RemoveCount=$taskRemove.Count;Bytes=($taskRemove | Measure-Object Bytes -Sum).Sum} | ConvertTo-Json -Compress | Write-Output
if($Apply){
 foreach($taskItem in $taskRemove){
  $taskTarget=Assert-GeneratedPath $taskItem.Path $taskItem.Parent
  Remove-Item -LiteralPath $taskTarget -Recurse -Force
 }
}
