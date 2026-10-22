# Startet den Tunnel (falls noetig) und ein eigenes Chrome-Profil, das komplett
# ueber den Tunnel laeuft. Normales Chrome und alle anderen Programme bleiben direkt.
. "$PSScriptRoot\common.ps1"

Start-Tunnel

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { throw "chrome.exe nicht gefunden." }

$profileDir = Join-Path $ClientDir 'chrome-profile'
Start-Process -FilePath $chrome -ArgumentList @(
    "--proxy-server=$ProxyUrl",
    "--user-data-dir=`"$profileDir`"",
    '--no-first-run'
)
