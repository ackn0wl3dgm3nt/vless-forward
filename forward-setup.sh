#!/bin/bash
# forward — проброс портов (DNAT) TCP/UDP на backend'ы.
#
#   forward            — добавить одно правило (вводишь по одному)
#   forward --bulk     — вставить сразу много правил (пустая строка или Ctrl+D — конец)
#   forward --flush    — очистить iptables
#
# Формат правила:  ENTRY_PORT  BACKEND[:PORT]  [tcp|udp|both]
#   8443  1.2.3.4
#   9443  5.6.7.8:443
#   10443 9.9.9.9:8880 both
#   12443 1.1.1.1 tcp
#   1332  2.2.2.2 udp
# Протокол по умолчанию: tcp. Порт backend по умолчанию: 8880.
# Диапазон входных портов тоже можно: 20000-20010 1.2.3.4:8880

set -e

DEFAULT_BACKEND_PORT=8880
DEFAULT_PROTO=tcp

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

MODE=single
for arg in "$@"; do
  case "$arg" in
    --flush) MODE=flush ;;
    --bulk)  MODE=bulk ;;
    -h|--help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *) echo "Неизвестный аргумент: $arg (см. --help)"; exit 1 ;;
  esac
done

# ---------- flush ----------
if [ "$MODE" = "flush" ]; then
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

# ---------- сбор правил ----------
RULES=()

add_rule() {
  local line="${1%%#*}"
  line="$(echo "$line" | xargs)"
  [ -z "$line" ] && return 0
  RULES+=("$line")
}

if [ "$MODE" = "bulk" ]; then
  echo "Вставь правила (ENTRY_PORT BACKEND[:PORT] [tcp|udp|both]),"
  echo "пустая строка или Ctrl+D — конец:"
  while IFS= read -r l; do
    [ -z "$l" ] && break
    add_rule "$l"
  done
else
  read -rp "Entry port (на этой машине): " ENTRY_PORT
  read -rp "Backend (ip или ip:port, по умолчанию порт $DEFAULT_BACKEND_PORT): " BACKEND
  read -rp "Протокол [tcp/udp/both] (по умолчанию $DEFAULT_PROTO): " PROTO_IN
  add_rule "$ENTRY_PORT $BACKEND $PROTO_IN"
fi

if [ ${#RULES[@]} -eq 0 ]; then
  echo "Нет правил."
  exit 1
fi

# ---------- интерфейс ----------
IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
if [ -z "$IFACE" ]; then
  echo "Не удалось определить дефолтный интерфейс"
  exit 1
fi
echo "Interface: $IFACE"

# ---------- ip_forward ----------
echo "[*] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
if grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf 2>/dev/null; then
  sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
else
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# ---------- iptables-persistent ----------
if ! command -v netfilter-persistent >/dev/null 2>&1; then
  echo "[*] Installing iptables-persistent..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y iptables-persistent
fi

# ---------- общие правила (один раз) ----------
if ! iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null; then
  echo "[*] Enabling masquerading on $IFACE..."
  iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
fi

if ! iptables -C FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; then
  iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
fi

# ensure [-t table] CHAIN rule... — добавить правило, только если его ещё нет
ensure() {
  local table=""
  if [ "$1" = "-t" ]; then table="$2"; shift 2; fi
  local chain="$1"; shift
  if [ -n "$table" ]; then
    iptables -t "$table" -C "$chain" "$@" 2>/dev/null || iptables -t "$table" -A "$chain" "$@"
  else
    iptables -C "$chain" "$@" 2>/dev/null || iptables -A "$chain" "$@"
  fi
}

# ---------- применение ----------
OK=0
FAIL=0
for r in "${RULES[@]}"; do
  read -r ENTRY BACKEND PROTO <<< "$r"
  PROTO="${PROTO:-$DEFAULT_PROTO}"

  if [[ -z "$ENTRY" || -z "$BACKEND" ]]; then
    echo "[!] Пропуск (некорректно): $r"; FAIL=$((FAIL+1)); continue
  fi

  BIP="${BACKEND%%:*}"
  if [[ "$BACKEND" == *:* ]]; then
    BPORT="${BACKEND##*:}"
  else
    BPORT="$DEFAULT_BACKEND_PORT"
  fi
  DPORT="${ENTRY/-/:}"

  if ! [[ "$DPORT" =~ ^[0-9]+(:[0-9]+)?$ && "$BPORT" =~ ^[0-9]+$ && "$BIP" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
    echo "[!] Пропуск (некорректно): $r"; FAIL=$((FAIL+1)); continue
  fi

  case "$PROTO" in
    tcp)  PROTOS=(tcp) ;;
    udp)  PROTOS=(udp) ;;
    both) PROTOS=(tcp udp) ;;
    *) echo "[!] Неизвестный протокол '$PROTO' в: $r"; FAIL=$((FAIL+1)); continue ;;
  esac

  for p in "${PROTOS[@]}"; do
    ensure -t nat PREROUTING -p "$p" --dport "$DPORT" -j DNAT --to-destination "$BIP:$BPORT"
    ensure FORWARD -p "$p" -d "$BIP" --dport "$BPORT" -j ACCEPT
    echo "[+] $p $ENTRY -> $BIP:$BPORT"
  done
  OK=$((OK+1))
done

echo "[*] Saving iptables rules..."
netfilter-persistent save >/dev/null

echo "[+] Done. Применено: $OK, пропущено: $FAIL"
