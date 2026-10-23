# Gemeinsame Funktionen fuer die Tunnel-Skripte. Wird per Dot-Sourcing geladen.
$ErrorActionPreference = 'Stop'

$ClientDir = Split-Path $PSScriptRoot -Parent
$ConfigPath = Join-Path $ClientDir 'config.ps1'
if (-not (Test-Path $ConfigPath)) {
    throw "config.ps1 fehlt. config.example.ps1 nach config.ps1 kopieren und ausfuellen."
}
. $ConfigPath

$WstunnelVersion = '11.1.0'   # passend zum Server-Image in server/docker-compose.yml
$Exe = Join-Path $ClientDir 'bin\wstunnel.exe'
$LogDir = Join-Path $ClientDir 'logs'
$ProxyUrl = "http://$LocalProxy"

function Get-TunnelArgs([string]$LogLevel) {
    # Windows-Resolver statt des eingebauten: Manche DNS-Server liefern EDNS-Antworten,
    # die wstunnel nicht lesen kann. Dann scheitert jede Verbindung, und mit -c wartet
    # der Client endlos auf den Pool, bevor er den lokalen Port oeffnet.
    $tunnelArgs = @('client', '-L', "http://$LocalProxy", '-c', '2', '--log-lvl', $LogLevel,
        '--dns-resolver', 'system://0.0.0.0')
    if (-not $SkipTlsVerify) { $tunnelArgs += '--tls-verify-certificate' }
    if ($UpstreamProxy) { $tunnelArgs += @('--http-proxy', $UpstreamProxy) }
    if ($UpstreamProxyUser) { $tunnelArgs += @('--http-proxy-login', $UpstreamProxyUser) }
    $tunnelArgs += $TunnelServer
    return $tunnelArgs
}

# Secret und Proxy-Passwort gehen per Umgebung an wstunnel, damit sie nicht in
# der Kommandozeile stehen (Prozesslisten, EDR-Protokolle). HTTP_PROXY wird
# entfernt, weil wstunnel es sonst als Upstream-Proxy uebernimmt. NO_COLOR liest
# wstunnel ebenfalls und akzeptiert nur true/false (ein gesetztes NO_COLOR=1 bricht den Start).
function Invoke-WithTunnelEnv([scriptblock]$Action) {
    $names = 'WSTUNNEL_HTTP_UPGRADE_PATH_PREFIX', 'WSTUNNEL_HTTP_PROXY_PASSWORD', 'HTTP_PROXY', 'NO_COLOR'
    $saved = @{}
    foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process') }
    try {
        $env:NO_COLOR = 'true'
        $env:WSTUNNEL_HTTP_UPGRADE_PATH_PREFIX = $TunnelSecret
        if ($UpstreamProxyPassword) { $env:WSTUNNEL_HTTP_PROXY_PASSWORD = $UpstreamProxyPassword }
        Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
        & $Action
    } finally {
        foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $saved[$n], 'Process') }
    }
}

function Test-TunnelListening {
    $parts = $LocalProxy.Split(':')
    $client = New-Object System.Net.Sockets.TcpClient
    # Connect() auf einen geschlossenen Port dauert unter Windows ~2 s (SYN-Wiederholungen)
    try { return $client.ConnectAsync($parts[0], [int]$parts[1]).Wait(500) -and $client.Connected }
    catch { return $false }
    finally { $client.Close() }
}

function Get-TunnelProcess {
    Get-Process wstunnel -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe }
}

# wstunnel.exe liegt nicht im Repo. Beim ersten Start wird das offizielle Release
# geladen und gegen die checksums.txt des Releases geprueft.
function Install-Wstunnel {
    if (Test-Path $Exe) { return }
    $base = "https://github.com/erebe/wstunnel/releases/download/v$WstunnelVersion"
    $archiveName = "wstunnel_${WstunnelVersion}_windows_amd64.tar.gz"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "tunnler-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $oldProgress = $ProgressPreference
    try {
        Write-Host "Lade wstunnel $WstunnelVersion ..."
        $ProgressPreference = 'SilentlyContinue'   # sonst ist Invoke-WebRequest in PS 5.1 sehr langsam
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $archive = Join-Path $tmp $archiveName
        $sums = Join-Path $tmp 'checksums.txt'
        Invoke-WebRequest "$base/$archiveName" -OutFile $archive -UseBasicParsing
        Invoke-WebRequest "$base/checksums.txt" -OutFile $sums -UseBasicParsing
        $line = Get-Content $sums | Where-Object { $_ -match "\s$([regex]::Escape($archiveName))$" }
        if (-not $line) { throw "$archiveName fehlt in checksums.txt." }
        if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne ($line -split '\s+')[0]) {
            throw "Pruefsumme von $archiveName stimmt nicht. Download verworfen."
        }
        & "$env:SystemRoot\System32\tar.exe" -xzf $archive -C $tmp wstunnel.exe
        if ($LASTEXITCODE -ne 0) { throw "Entpacken von $archiveName fehlgeschlagen." }
        New-Item -ItemType Directory -Force (Split-Path $Exe) | Out-Null
        Move-Item (Join-Path $tmp 'wstunnel.exe') $Exe
    } finally {
        $ProgressPreference = $oldProgress
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

# Startet den Client unsichtbar im Hintergrund, falls er noch nicht laeuft.
function Start-Tunnel {
    if (-not $TunnelSecret) { throw "TunnelSecret in config.ps1 ist leer." }
    if (Test-TunnelListening) { return }
    Install-Wstunnel
    New-Item -ItemType Directory -Force $LogDir | Out-Null
    $log = Join-Path $LogDir 'wstunnel.log'
    Invoke-WithTunnelEnv {
        Start-Process -FilePath $Exe -ArgumentList (Get-TunnelArgs 'WARN') -WindowStyle Hidden `
            -RedirectStandardOutput $log -RedirectStandardError (Join-Path $LogDir 'wstunnel.err.log')
    }
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-TunnelListening) { return }
        Start-Sleep -Milliseconds 250
    }
    throw "Tunnel-Client lauscht nicht auf $LocalProxy. Details: $log"
}

function Stop-Tunnel {
    Get-TunnelProcess | Stop-Process -Force
}
