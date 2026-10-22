# Startet den Tunnel (falls noetig) und Codex mit Proxy-Variablen nur fuer diesen Aufruf.
# Alle Argumente werden an codex durchgereicht.
. "$PSScriptRoot\common.ps1"

Start-Tunnel

$names = 'HTTPS_PROXY', 'HTTP_PROXY', 'NO_PROXY'
$saved = @{}
foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process') }
try {
    $env:HTTPS_PROXY = $ProxyUrl
    $env:HTTP_PROXY = $ProxyUrl
    $env:NO_PROXY = 'localhost,127.0.0.1'
    & codex @args
} finally {
    foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $saved[$n], 'Process') }
}
