param(
    [string]$Server = '62.238.49.219',
    [string]$KeyPath = (Join-Path $env:USERPROFILE '.ssh/hetzner_twitch_interaktion')
)
$ErrorActionPreference = 'Stop'
$musicFolder = Join-Path (Split-Path -Parent $PSScriptRoot) 'frontend/public/music/nullsignal'
$remoteFolder = '/opt/twitch-interaktion/frontend/public/music/nullsignal'
$songs = @('menu.mp3','ingame.mp3') | Where-Object { Test-Path -LiteralPath (Join-Path $musicFolder $_) }
if (!$songs) { throw "Lege menu.mp3 und/oder ingame.mp3 in $musicFolder ab." }
if (!(Test-Path -LiteralPath $KeyPath)) { throw "SSH-Schlüssel fehlt: $KeyPath" }
foreach ($song in $songs) {
    $source = Join-Path $musicFolder $song
    if ((Get-Item -LiteralPath $source).Length -eq 0) { throw "$song ist leer." }
    $stagedName = '.upload-' + [Guid]::NewGuid().ToString('N') + '-' + $song
    & scp -i $KeyPath -o BatchMode=yes -o ConnectTimeout=12 -- $source "root@${Server}:$remoteFolder/$stagedName"
    if ($LASTEXITCODE -ne 0) { throw "Upload für $song fehlgeschlagen; bisheriger Song bleibt erhalten." }
    & ssh -i $KeyPath -o BatchMode=yes -o ConnectTimeout=12 "root@$Server" "chmod 644 '$remoteFolder/$stagedName' && mv -- '$remoteFolder/$stagedName' '$remoteFolder/$song'"
    if ($LASTEXITCODE -ne 0) { throw "Freigabe für $song fehlgeschlagen." }
    Write-Host "$song ist live. Spielseite neu laden."
}
