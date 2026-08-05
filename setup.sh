#!/bin/bash
set -e

FLUSH=0
for arg in "$@"; do
  case "$arg" in
    --flush) FLUSH=1 ;;
  esac
done

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

if [ "$FLUSH" -eq 1 ]; then
  echo "[*] --flush указан: очищаю iptables rules..."
  iptables -F
  iptables -t nat -F
  iptables -t mangle -F

  echo "[*] Setting default policies..."
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT

  export DEBIAN_FRONTEND=noninteractive
  if command -v netfilter-persistent >/dev/null 2>&1; then
    echo "[*] Сохраняю пустые правила..."
    netfilter-persistent save
  fi

  echo "[+] iptables очищен."
  exit 0
fi

DEFAULT_BACKEND_PORT=8880

read -rp "Entry port (на этой машине): " ENTRY_PORT
read -rp "Backend (ip или ip:port, по умолчанию порт $DEFAULT_BACKEND_PORT): " BACKEND

BACKEND_IP="${BACKEND%%:*}"
if [[ "$BACKEND" == *:* ]]; then
  BACKEND_PORT="${BACKEND##*:}"
else
  BACKEND_PORT="$DEFAULT_BACKEND_PORT"
fi

if [[ -z "$ENTRY_PORT" || -z "$BACKEND_IP" || -z "$BACKEND_PORT" ]]; then
  echo "Некорректный ввод. Формат backend: ip или ip:port"
  exit 1
fi

IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
if [ -z "$IFACE" ]; then
  echo "Не удалось определить дефолтный интерфейс"
  exit 1
fi

echo "Entry port: $ENTRY_PORT"
echo "Backend: $BACKEND_IP:$BACKEND_PORT"
echo "Interface: $IFACE"

echo "[*] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
if ! grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf 2>/dev/null; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
else
  sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
fi

echo "[*] Installing iptables-persistent..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y iptables-persistent

echo "[*] Adding DNAT rule for port $ENTRY_PORT -> $BACKEND_IP:$BACKEND_PORT..."
iptables -t nat -A PREROUTING -p tcp --dport "$ENTRY_PORT" -j DNAT --to-destination "$BACKEND_IP:$BACKEND_PORT"

if ! iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null; then
  echo "[*] Enabling masquerading on $IFACE..."
  iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
else
  echo "[*] Masquerade правило уже есть, пропускаю"
fi

echo "[*] Allowing forwarding for port $ENTRY_PORT..."
iptables -A FORWARD -p tcp --dport "$ENTRY_PORT" -j ACCEPT

echo "[*] Allowing established/related return traffic..."
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "[*] Saving iptables rules..."
netfilter-persistent save

echo "[+] Done. $ENTRY_PORT -> $BACKEND_IP:$BACKEND_PORT"
