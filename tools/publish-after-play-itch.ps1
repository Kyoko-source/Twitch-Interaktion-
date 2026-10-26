param(
 [string]$Project='kyokohauntedgames/after-play',
 [ValidateSet('Both','Windows','Web')][string]$Platform='Both',
 [switch]$Upload
)
$ErrorActionPreference='Stop'
$taskRepo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskBuild=Join-Path $taskRepo 'games/kinderparadies/build'
$taskButler=Join-Path $taskRepo 'tools/art-source/butler/butler.exe'
$taskManifest=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $taskBuild 'release.json') | ConvertFrom-Json
if($Project -notmatch '^[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$'){throw 'Project must be lower-case username/game, for example kyokohauntedgames/after-play'}
if($taskManifest.version -notmatch '^\d+\.\d+\.\d+$' -or $taskManifest.packaging_revision -ne 2){throw 'Invalid or outdated release manifest. Package the game first.'}
if(-not (Test-Path -LiteralPath $taskButler)){throw 'Run tools/setup-after-play-butler.ps1 once before preparing an upload.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Stream-Hash([IO.Stream]$Stream){
 $taskSha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($taskSha.ComputeHash($Stream))).Replace('-','').ToLowerInvariant()}
 finally{$taskSha.Dispose()}
}
function Check-UploadTree([string]$Directory,[string]$Archive,[string]$ExpectedHash){
 if((Get-FileHash -Algorithm SHA256 -LiteralPath $Archive).Hash.ToLowerInvariant() -ne $ExpectedHash){throw "Release checksum mismatch: $Archive"}
 $taskRoot=(Resolve-Path -LiteralPath $Directory).Path
 if((Get-Item -LiteralPath $taskRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Upload directory must not be a link'}
 $taskItems=@(Get-ChildItem -LiteralPath $taskRoot -Recurse -Force)
 if($taskItems | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}){throw 'Upload tree contains a link'}
 $taskFiles=@($taskItems | Where-Object {-not $_.PSIsContainer})
 $taskZip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try{
  $taskEntries=@($taskZip.Entries | Where-Object {$_.Name})
  if($taskFiles.Count -ne $taskEntries.Count){throw "Unexpected files in player upload: $Directory"}
  foreach($taskEntry in $taskEntries){
   $taskRelative=$taskEntry.FullName.Replace('\','/')
   if($taskRelative.StartsWith('/') -or '..' -in $taskRelative.Split('/')){throw 'Unsafe package entry'}
   $taskFile=Join-Path $taskRoot $taskRelative
   if(-not (Test-Path -LiteralPath $taskFile -PathType Leaf)){throw "Missing upload file: $taskRelative"}
   $taskStream=$taskEntry.Open()
   try{$taskDigest=Stream-Hash $taskStream}finally{$taskStream.Dispose()}
   if((Get-FileHash -Algorithm SHA256 -LiteralPath $taskFile).Hash.ToLowerInvariant() -ne $taskDigest){throw "Packaged file was changed: $taskRelative"}
  }
 }finally{$taskZip.Dispose()}
}
$taskJobs=@()
if($Platform -in @('Both','Windows')){$taskJobs+=@{channel='windows';directory=(Join-Path $taskBuild 'player-package');archive=(Join-Path $taskBuild "after-play-windows-v$($taskManifest.version).zip");sha=$taskManifest.windows_sha256}}
if($Platform -in @('Both','Web')){$taskJobs+=@{channel='web';directory=(Join-Path $taskBuild 'browser-package');archive=(Join-Path $taskBuild "after-play-web-v$($taskManifest.version).zip");sha=$taskManifest.web_zip_sha256}}
# Validate every selected channel before the first possible upload. Upload only
# the exact clean player trees; developer tools and videos stay outside them.
foreach($taskJob in $taskJobs){Check-UploadTree $taskJob.directory $taskJob.archive $taskJob.sha}
$taskPlan=[ordered]@{project=$Project;version=$taskManifest.version;mode=$(if($Upload){'upload'}else{'local-dry-run'});channels=@($taskJobs | ForEach-Object {[ordered]@{channel=$_.channel;directory=$_.directory;zip_sha256=$_.sha}})}
[IO.File]::WriteAllText((Join-Path $taskBuild 'itch-upload-plan.json'),($taskPlan | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
Write-Host "Project: $Project; version: $($taskManifest.version)"
if(-not $Upload){Write-Host 'LOCAL PREVIEW: nothing is uploaded. Confirm the game slug before your first upload.'}
foreach($taskJob in $taskJobs){
 $taskArguments=@('push',$taskJob.directory,($Project+':'+$taskJob.channel),'--userversion',$taskManifest.version)
 if(-not $Upload){$taskArguments+='--dry-run'}
 & $taskButler @taskArguments
 if($LASTEXITCODE -ne 0){throw "Butler failed for $($taskJob.channel); no further channel will be started. For actual uploads, log in once with tools/art-source/butler/butler.exe login. Retry a failed channel with -Platform Windows or -Platform Web."}
}
if($Upload){Write-Host 'Upload complete. Check both channels on the itch.io Edit game page.'}
else{Write-Host 'Selected package trees verified. To publish later, rerun with -Upload and the confirmed -Project username/game.'}
