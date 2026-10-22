# Als config.ps1 speichern und ausfuellen.
# config.ps1 enthaelt das Tunnel-Secret: nicht weitergeben, nicht committen.

# Geheimer Pfad, identisch mit server/restrictions.yaml und der NPM-Location
$TunnelSecret = ''
$TunnelServer = 'wss://deine-domain.de:443'

# Lokaler Proxy, auf den Chrome und Codex zeigen
$LocalProxy = '127.0.0.1:1080'

# Firmen-Proxy aus der PAC-Datei, z. B. 'http://proxy.firma.de:8080'.
# Leer = direkte Verbindung (zu Hause, Hotspot).
$UpstreamProxy = ''
$UpstreamProxyUser = ''
$UpstreamProxyPassword = ''

# Nur auf $true setzen, wenn der Firmen-Proxy TLS aufbricht
# (Zertifikat der eigenen Domain im Browser nicht von Let's Encrypt).
$SkipTlsVerify = $false
