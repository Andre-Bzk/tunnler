# Installation

Schritt-für-Schritt-Einrichtung von Server (Raspberry Pi) und Client (Windows).
Alle Befehle sind zum Kopieren gedacht. Platzhalter in `GROSSBUCHSTABEN`
ersetzen.

Dauer: etwa 20 Minuten.

---

## Voraussetzungen

**Server**

- Raspberry Pi oder anderer Linux-Rechner mit Docker und Docker Compose
  (`docker compose version` funktioniert)
- [Nginx Proxy Manager](https://nginxproxymanager.com/) läuft dort in Docker
- Eine Domain zeigt auf deinen Internetanschluss. Im Router ist Port 443 an den
  Pi weitergeleitet.
- Im Nginx Proxy Manager gibt es für diese Domain einen Proxy Host mit gültigem
  SSL-Zertifikat. Ein neues Zertifikat bekommst du im Proxy Host über den Tab
  **SSL** → *Request a new SSL Certificate*.
- SSH-Zugang zum Pi mit einem Benutzer, der `sudo` darf

**Client**

- Windows 10 oder 11 mit Google Chrome
- Dieses Projekt als Ordner auf dem PC

---

## Teil 1 — Server

### 1.1 Dateien auf den Pi kopieren

In PowerShell im Projektordner (dort, wo `README.md` liegt):

```powershell
$Pi = 'BENUTZER@PI-ADRESSE'
ssh $Pi 'mkdir -p ~/wstunnel && chmod 700 ~/wstunnel'
scp server\docker-compose.yml server\restrictions.example.yaml server\firewall\tunnler-firewall.sh server\firewall\tunnler-firewall.service "${Pi}:wstunnel/"
```

Danach am Pi anmelden. Alle folgenden Befehle in Teil 1 laufen dort:

```powershell
ssh $Pi
```

### 1.2 Netz des Proxy Managers ermitteln

Der Tunnel-Container kommt in dasselbe Docker-Netz wie der Nginx Proxy Manager
und bekommt dort eine feste IP-Adresse.

```bash
cd ~/wstunnel
NPM_CONTAINER=$(docker ps --format '{{.Names}} {{.Image}}' | awk '/nginx-proxy-manager/ {print $1; exit}')
NPM_NETWORK=$(docker inspect "$NPM_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | head -n 1)
SUBNET=$(docker network inspect "$NPM_NETWORK" --format '{{(index .IPAM.Config 0).Subnet}}')
TUNNEL_IP=$(python3 -c 'import ipaddress, sys; print(ipaddress.ip_network(sys.argv[1])[-6])' "$SUBNET")
printf 'NPM_NETWORK=%s\nTUNNEL_IP=%s\n' "$NPM_NETWORK" "$TUNNEL_IP" > .env
echo "Proxy Manager: $NPM_CONTAINER | Netz: $NPM_NETWORK ($SUBNET) | Tunnel-IP: $TUNNEL_IP"
```

Die letzte Zeile muss einen Container, ein Netz und eine IP nennen, zum
Beispiel:

```
Proxy Manager: nginx-app-1 | Netz: nginx_default (172.20.0.0/16) | Tunnel-IP: 172.20.255.250
```

Ist ein Feld leer oder heißt das Netz `bridge`, siehe
[Fehlerbehebung](#fehlerbehebung).

### 1.3 Secret erzeugen

Das Secret ist das Passwort des Tunnels. Es wird Teil des URL-Pfads.

```bash
cd ~/wstunnel
SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
sed "s/__SECRET__/$SECRET/" restrictions.example.yaml > restrictions.yaml
chmod 644 restrictions.yaml
echo "Secret: $SECRET"
```

Das Secret in einem Passwort-Manager speichern. Es wird in Schritt 1.6 und 2.2
gebraucht.

### 1.4 Tunnel-Server starten

```bash
cd ~/wstunnel
docker compose up -d
docker logs wstunnel --tail 5
```

Docker lädt das Image `ghcr.io/erebe/wstunnel` beim ersten Start selbst
herunter. Die Version steht in `docker-compose.yml`. In der Log-Ausgabe muss
folgende Zeile stehen:

```
Starting wstunnel server listening on 0.0.0.0:8090
```

### 1.5 Firewall einrichten

Die Regeln sperren für den Tunnel-Container alle privaten Netze. Über den Tunnel
ist damit weder das Heimnetz noch der Pi selbst erreichbar.

```bash
cd ~/wstunnel
. ./.env
echo "TUNNEL_IP=$TUNNEL_IP" | sudo tee /etc/default/tunnler-firewall
sudo install -m 755 tunnler-firewall.sh /usr/local/sbin/
sudo install -m 644 tunnler-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tunnler-firewall
sudo iptables -S TUNNLER | head -n 3
```

Die Ausgabe beginnt mit `-N TUNNLER`. Die Regeln werden bei jedem Neustart
automatisch wieder gesetzt.

### 1.6 Nginx Proxy Manager konfigurieren

Die Werte für die Oberfläche anzeigen:

```bash
cd ~/wstunnel
. ./.env
SECRET=$(sed -n 's/.*PathPrefix "^\([A-Za-z0-9]*\)\$".*/\1/p' restrictions.yaml)
echo "Location: /$SECRET/"
echo "Forward:  http  $TUNNEL_IP  8090"
```

Im Nginx Proxy Manager **Hosts → Proxy Hosts** öffnen und beim Proxy Host der
Domain auf **Edit** klicken:

1. Tab **Details**: **Websockets Support** einschalten.
2. Tab **Custom Locations** → **Add location**:

   | Feld | Wert |
   |---|---|
   | Location | `/SECRET/` aus der Ausgabe oben, mit beiden Schrägstrichen |
   | Scheme | `http` |
   | Forward Hostname / IP | Tunnel-IP aus der Ausgabe oben, ohne Schrägstrich |
   | Forward Port | `8090` |

3. Beim Zahnrad der Location dieses Feld füllen:

   ```nginx
   proxy_read_timeout 3600s;
   proxy_send_timeout 3600s;
   proxy_buffering off;
   ```

4. **Save**. Der Proxy Host muss danach als *Online* angezeigt werden.

Die bestehende Website unter `/` bleibt unverändert.

---

## Teil 2 — Client

### 2.1 Ordner ablegen

In PowerShell im Projektordner:

```powershell
New-Item -ItemType Directory -Force C:\Tools | Out-Null
Copy-Item -Recurse client C:\Tools\tunnler
```

Ein anderer Zielordner geht genauso. Admin-Rechte sind nicht nötig.
`wstunnel.exe` lädt der erste Start von GitHub nach `bin\` und prüft dabei die
SHA-256-Prüfsumme.

### 2.2 Konfiguration anlegen

```powershell
cd C:\Tools\tunnler
Copy-Item config.example.ps1 config.ps1
notepad config.ps1
```

In `config.ps1` zwei Werte eintragen und speichern:

```powershell
$TunnelSecret = 'SECRET'
$TunnelServer = 'wss://DOMAIN:443'
```

### 2.3 Server-Weg prüfen

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" https://DOMAIN/SECRET/events
```

| Ergebnis | Bedeutung |
|---|---|
| `400` | Richtig: Die Anfrage erreicht den Tunnel-Server |
| `404` | Die Custom Location fehlt oder ist falsch geschrieben (1.6) |
| `502` | Der Container läuft nicht, oder die Forward-IP ist falsch (1.4, 1.6) |

### 2.4 Tunnel testen

`Chrome-Tunnel.cmd` doppelklicken. Es öffnet sich ein eigenes Chrome-Fenster.
Danach in PowerShell:

```powershell
cd C:\Tools\tunnler
.\Tunnel-Status.cmd
```

Die angezeigte IP muss die IP des Internetanschlusses zu Hause sein. Für einen
echten Test den PC mit einem Handy-Hotspot verbinden: Die IP darf dann nicht die
des Hotspots sein.

### 2.5 `codexx` einrichten

`PATH-eintragen.cmd` doppelklicken. Der Client-Ordner landet im Benutzer-PATH,
Admin-Rechte sind nicht nötig. Danach VS Code und alle Terminals komplett neu
starten. In jedem Projektordner startet `codexx` statt `codex` Codex über den
Tunnel.

Nach dem Verschieben des Client-Ordners den alten Eintrag unter
*Umgebungsvariablen für dieses Konto bearbeiten* → `Path` löschen und
`PATH-eintragen.cmd` erneut ausführen.

---

## Teil 3 — Einsatz hinter einem Firmen-Proxy

Netze mit erzwungenem Proxy lassen keine direkte Verbindung zu. Der Tunnel muss
dort durch den Proxy.

### 3.1 Proxy-Adresse herausfinden

```powershell
(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings").AutoConfigURL
```

Die angezeigte URL im Browser öffnen. In der PAC-Datei nach einer Zeile wie
`PROXY proxy.firma.de:8080` suchen.

### 3.2 Proxy eintragen

In `config.ps1`:

```powershell
$UpstreamProxy = 'http://PROXY-HOST:PROXY-PORT'
```

Verlangt der Proxy eine Anmeldung, zusätzlich `$UpstreamProxyUser` und
`$UpstreamProxyPassword` setzen. Danach `Tunnel-Stop.cmd` ausführen und
`Chrome-Tunnel.cmd` neu starten.

### 3.3 Wenn der Proxy TLS aufbricht

In Edge `https://DOMAIN` öffnen, auf das Schloss klicken und das Zertifikat
ansehen. Ist der Aussteller nicht *Let's Encrypt*, bricht der Proxy die
Verschlüsselung auf. Der Tunnel scheitert dann an der Zertifikatsprüfung. Nur
in diesem Fall in `config.ps1` setzen:

```powershell
$SkipTlsVerify = $true
```

Der Proxy sieht dann das Secret. Nach dem Einsatz das Secret tauschen.

---

## Secret tauschen

Auf dem Pi:

```bash
cd ~/wstunnel
OLD=$(sed -n 's/.*PathPrefix "^\([A-Za-z0-9]*\)\$".*/\1/p' restrictions.yaml)
NEW=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
sed -i "s/$OLD/$NEW/" restrictions.yaml
echo "Neues Secret: $NEW"
```

Der Server lädt die Datei automatisch neu. Danach:

1. Im Nginx Proxy Manager die Custom Location auf `/NEUES-SECRET/` ändern und
   speichern.
2. Auf jedem PC in `config.ps1` `$TunnelSecret` ersetzen, dann `Tunnel-Stop.cmd`
   ausführen.

---

## Aktualisieren

In `~/wstunnel/docker-compose.yml` die Image-Version erhöhen
([Releases](https://github.com/erebe/wstunnel/releases)), dann:

```bash
cd ~/wstunnel
docker compose pull
docker compose up -d
```

Den Client auf dieselbe Version bringen: In `client\scripts\common.ps1`
`$WstunnelVersion` anpassen, `Tunnel-Stop.cmd` ausführen und
`client\bin\wstunnel.exe` löschen. Der nächste Start lädt die neue Version.

---

## Deinstallieren

1. Im Nginx Proxy Manager die Custom Location entfernen.
2. Auf dem Pi:

   ```bash
   cd ~/wstunnel && docker compose down
   sudo systemctl disable --now tunnler-firewall
   sudo rm /etc/systemd/system/tunnler-firewall.service /usr/local/sbin/tunnler-firewall.sh /etc/default/tunnler-firewall
   sudo systemctl daemon-reload
   rm -r ~/wstunnel
   ```

3. Auf dem PC den Client-Ordner löschen. Es wurde nichts installiert.

---

## Fehlerbehebung

| Symptom | Lösung |
|---|---|
| 1.2: `Proxy Manager:` ist leer | Der Container heißt anders. `docker ps` ausführen und den Namen von Hand setzen: `NPM_CONTAINER=NAME`, dann ab der zweiten Zeile wiederholen. |
| 1.2: Netz heißt `bridge` | Im Standardnetz sind keine festen IPs möglich. Den Proxy Manager in ein eigenes Netz verschieben, zum Beispiel per Docker Compose. |
| 1.4: `Address already in use` / `invalid address` | Die Tunnel-IP ist belegt oder liegt außerhalb des Subnetzes. In `~/wstunnel/.env` eine andere freie IP aus dem Subnetz eintragen und 1.4 bis 1.6 wiederholen. |
| 1.6: Proxy Host *Offline* | Die Location in NPM löschen und Schreibweise prüfen. Im Feld *Forward Hostname* darf kein Pfad stehen. |
| Client: `Tunnel-Client lauscht nicht` | `logs\wstunnel.err.log` im Client-Ordner lesen. Ein anderes Programm nutzt eventuell Port 1080; dann `$LocalProxy` in `config.ps1` ändern. |
| Client verbindet nicht, Timeout | Im Firmennetz fehlt `$UpstreamProxy` (3.2). Sonst Portweiterleitung und DNS der Domain prüfen. |
| Seite lädt nicht, Client-Log zeigt `400` | Das Ziel ist gesperrt (nur Ports 80/443, keine privaten Adressen). Den Grund zeigt `docker logs wstunnel` auf dem Pi in der Zeile `Rejecting …`. |
| Codex nutzt den Tunnel nicht | Codex mit `codexx` starten, nicht direkt mit `codex`. Fehlt der Befehl, `PATH-eintragen.cmd` ausführen (2.5). |
