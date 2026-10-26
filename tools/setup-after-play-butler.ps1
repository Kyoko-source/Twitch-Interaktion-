param()
$ErrorActionPreference='Stop'
$taskRepo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskDirectory=Join-Path $taskRepo 'tools/art-source/butler'
$taskVersion='15.32.0'
$taskHash='5902c488b86bb3518ca00bf4e706d7687f229e3f0f28653cd943348ea9ec8878'
$taskArchive=Join-Path $taskDirectory "butler-$taskVersion.zip"
New-Item -ItemType Directory -Path $taskDirectory -Force | Out-Null
if(-not (Test-Path -LiteralPath $taskArchive)){
 Invoke-WebRequest -UseBasicParsing -Uri "https://broth.itch.zone/butler/windows-amd64/$taskVersion/archive.zip" -OutFile $taskArchive
}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $taskArchive).Hash.ToLowerInvariant() -ne $taskHash){throw 'Butler archive checksum mismatch. Nothing was installed.'}
Expand-Archive -LiteralPath $taskArchive -DestinationPath $taskDirectory -Force
& (Join-Path $taskDirectory 'butler.exe') version
if($LASTEXITCODE -ne 0){throw 'Butler did not start'}
Write-Host 'Installed privately in tools/art-source/butler. No login or upload performed.'
