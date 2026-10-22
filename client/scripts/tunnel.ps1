# Tunnel-Client verwalten.
#   tunnel.ps1 start   Client im Hintergrund starten, Proxy fuer beliebige Programme
#   tunnel.ps1 status  laeuft der Client, und welche IP sieht das Internet?
#   tunnel.ps1 stop    Client beenden
#   tunnel.ps1 run     Client im Vordergrund mit ausfuehrlichem Log (Fehlersuche)
param([ValidateSet('start', 'status', 'stop', 'run')][string]$Action = 'status')
. "$PSScriptRoot\common.ps1"

switch ($Action) {
    'start' {
        Start-Tunnel
        Write-Host "Tunnel laeuft. In den gewuenschten Programmen als HTTP-Proxy eintragen: $LocalProxy"
        Write-Host "Beenden mit Tunnel-Stop.cmd."
    }
    'status' {
        if (-not (Test-TunnelListening)) { Write-Host "Tunnel laeuft nicht."; break }
        Write-Host "Tunnel lauscht auf $LocalProxy."
        $ip = & curl.exe -s -m 15 -x $ProxyUrl https://api.ipify.org
        if ($LASTEXITCODE -eq 0) { Write-Host "Oeffentliche IP ueber den Tunnel: $ip" }
        else { Write-Host "Keine Verbindung durch den Tunnel. Log: $(Join-Path $LogDir 'wstunnel.log')" }
    }
    'stop' {
        Stop-Tunnel
        Write-Host "Tunnel beendet."
    }
    'run' {
        Stop-Tunnel
        Install-Wstunnel
        Invoke-WithTunnelEnv { & $Exe @(Get-TunnelArgs 'INFO') }
    }
}
