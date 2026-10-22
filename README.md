# Tunnler

[English](#english) | [Deutsch](#deutsch)

---

## English

> **Disclaimer:** This tool was vibe coded with Claude Code — architecture and structure were planned together with AI, and all implementation was done through prompts. Not a single line was written by hand.

Routes only Chrome and Codex through a wstunnel server on a home Raspberry Pi, even behind a corporate proxy that blocks sites.

Unlike a web proxy, the tunnel passes raw TCP connections. TLS ends at the real server, so Google and ChatGPT logins work.

### Features

- Local proxy on `127.0.0.1:1080`, used only by a dedicated Chrome profile and Codex
- Tunnel as WebSocket over `wss://` on port 443, optionally through a corporate proxy
- Access only via a secret URL path
- Server allows only TCP 80/443 to public destinations, the home network is blocked
- Client needs no admin rights and runs on Windows PowerShell 5.1

### Installation

Prerequisites:

- Raspberry Pi with Docker and Nginx Proxy Manager, own domain with SSL certificate
- Windows 10/11 with Google Chrome

Step-by-step guide for server and client (German): [docs/installation.md](docs/installation.md)

### Usage

Double-click `client\Chrome-Tunnel.cmd`. The tunnel starts hidden in the background, then a separate Chrome window opens that runs entirely through the Pi.

Run `client\PATH-eintragen.cmd` once. Afterwards type `codexx` instead of `codex` in any project folder, for example in the VS Code terminal. Arguments are passed through.

`Tunnel-Start.cmd` starts only the tunnel. Then set `127.0.0.1:1080` as HTTP proxy in any program. `Tunnel-Status.cmd` shows the public IP through the tunnel. `Tunnel-Stop.cmd` stops the tunnel.

### Configuration

All client values live in `client\config.ps1` (copy from `config.example.ps1`).

| Variable | Meaning | Default |
|---|---|---|
| `$TunnelSecret` | Secret path, identical to the server | empty |
| `$TunnelServer` | Server address | `wss://deine-domain.de:443` |
| `$LocalProxy` | Local proxy for Chrome and Codex | `127.0.0.1:1080` |
| `$UpstreamProxy` | Corporate proxy, empty = direct | empty |
| `$UpstreamProxyUser` / `$UpstreamProxyPassword` | Corporate proxy login | empty |
| `$SkipTlsVerify` | Disable certificate check, only if the proxy breaks TLS | `$false` |

After a change, run `client\Tunnel-Stop.cmd` and start the tunnel again.

### Known blockers

- On a corporate network the tunnel times out without `$UpstreamProxy`. See [corporate proxy](docs/installation.md#teil-3--einsatz-hinter-einem-firmen-proxy).
- The first start downloads `wstunnel.exe` from GitHub. Without access to github.com, place it in `client\bin\` manually.
- Private addresses such as `192.168.x.x` are blocked through the tunnel. The client log then shows `Invalid status code: 400`. Add them to the program's proxy exceptions.
- `client\config.ps1` and `server/restrictions.yaml` contain the secret. Do not share or commit them.

### Further documentation

- [docs/installation.md](docs/installation.md) — installation, corporate proxy, rotating the secret, updating, troubleshooting (German)
- [wstunnel](https://github.com/erebe/wstunnel) — the tunnel software used

---

## Deutsch

> **Hinweis:** Dieses Tool wurde mit Claude Code vibe coded — Architektur und Struktur wurden gemeinsam mit KI geplant, die gesamte Implementierung erfolgte per Prompt. Keine einzige Zeile wurde von Hand geschrieben.

Leitet nur Chrome und Codex über einen wstunnel-Server auf dem Raspberry Pi zu Hause ins Internet, auch hinter einem Firmen-Proxy, der Seiten sperrt.

Anders als ein Web-Proxy reicht der Tunnel reine TCP-Verbindungen durch. TLS endet beim echten Server, daher funktionieren Google- und ChatGPT-Logins.

### Funktionen

- Lokaler Proxy auf `127.0.0.1:1080`, den nur ein eigenes Chrome-Profil und Codex nutzen
- Tunnel als WebSocket über `wss://` auf Port 443, optional durch einen Firmen-Proxy
- Zugang nur mit geheimem URL-Pfad
- Server erlaubt nur TCP 80/443 zu öffentlichen Zielen, das Heimnetz ist gesperrt
- Client ohne Admin-Rechte, läuft mit Windows PowerShell 5.1

### Installation

Voraussetzungen:

- Raspberry Pi mit Docker und Nginx Proxy Manager, eigene Domain mit SSL-Zertifikat
- Windows 10/11 mit Google Chrome

Schritt-für-Schritt-Anleitung für Server und Client: [docs/installation.md](docs/installation.md)

### Nutzung

`client\Chrome-Tunnel.cmd` doppelklicken. Der Tunnel startet unsichtbar im Hintergrund, danach öffnet sich ein eigenes Chrome-Fenster, das komplett über den Pi läuft.

Einmal `client\PATH-eintragen.cmd` ausführen. Danach in jedem Projektordner `codexx` statt `codex` eingeben, zum Beispiel im VS-Code-Terminal. Argumente werden durchgereicht.

`Tunnel-Start.cmd` startet nur den Tunnel. Danach `127.0.0.1:1080` in beliebigen Programmen als HTTP-Proxy eintragen. `Tunnel-Status.cmd` zeigt die öffentliche IP über den Tunnel. `Tunnel-Stop.cmd` beendet den Tunnel.

### Konfiguration

Alle Client-Werte stehen in `client\config.ps1` (Vorlage: `config.example.ps1`).

| Variable | Bedeutung | Standard |
|---|---|---|
| `$TunnelSecret` | Geheimer Pfad, identisch mit dem Server | leer |
| `$TunnelServer` | Adresse des Servers | `wss://deine-domain.de:443` |
| `$LocalProxy` | Lokaler Proxy für Chrome und Codex | `127.0.0.1:1080` |
| `$UpstreamProxy` | Firmen-Proxy, leer = direkt | leer |
| `$UpstreamProxyUser` / `$UpstreamProxyPassword` | Anmeldung am Firmen-Proxy | leer |
| `$SkipTlsVerify` | Zertifikatsprüfung abschalten, nur bei TLS-Aufbruch | `$false` |

Nach einer Änderung `client\Tunnel-Stop.cmd` ausführen und den Tunnel neu starten.

### Bekannte Stolpersteine

- Im Firmennetz läuft der Tunnel ohne `$UpstreamProxy` in einen Timeout. Siehe [Einsatz hinter einem Firmen-Proxy](docs/installation.md#teil-3--einsatz-hinter-einem-firmen-proxy).
- Der erste Start lädt `wstunnel.exe` von GitHub. Ohne Zugriff auf github.com die Datei von Hand nach `client\bin\` legen.
- Private Adressen wie `192.168.x.x` sind über den Tunnel gesperrt. Das Client-Log zeigt dann `Invalid status code: 400`. Solche Adressen im Programm als Proxy-Ausnahme eintragen.
- `client\config.ps1` und `server/restrictions.yaml` enthalten das Secret. Nicht weitergeben und nicht committen.

### Weitere Dokumentation

- [docs/installation.md](docs/installation.md) — Installation, Firmen-Proxy, Secret tauschen, Aktualisieren, Fehlerbehebung
- [wstunnel](https://github.com/erebe/wstunnel) — verwendete Tunnel-Software
