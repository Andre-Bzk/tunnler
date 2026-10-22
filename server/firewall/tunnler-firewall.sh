#!/bin/sh
# Trennt den wstunnel-Container (feste IP, TUNNEL_IP aus /etc/default/tunnler-firewall) vom Heimnetz
# und vom Pi selbst. Hostnamen, die per oeffentlichem DNS auf private IPs zeigen
# (z. B. 192-168-0-1.nip.io), kann wstunnel selbst nicht abfangen.
#   tunnler-firewall.sh           Regeln setzen (idempotent)
#   tunnler-firewall.sh --remove  Regeln entfernen
set -e
SRC=${TUNNEL_IP:-172.20.250.250}

for chain in DOCKER-USER INPUT; do
  while iptables -D "$chain" -s "$SRC" -j TUNNLER 2>/dev/null; do :; done
done
if [ "$1" = "--remove" ]; then
  iptables -F TUNNLER 2>/dev/null || true
  iptables -X TUNNLER 2>/dev/null || true
  exit 0
fi

iptables -N TUNNLER 2>/dev/null || iptables -F TUNNLER
iptables -A TUNNLER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
for net in 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16; do
  iptables -A TUNNLER -d "$net" -j DROP
done

iptables -N DOCKER-USER 2>/dev/null || true
iptables -I DOCKER-USER -s "$SRC" -j TUNNLER
iptables -I INPUT -s "$SRC" -j TUNNLER
