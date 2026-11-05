#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

REPO_RAW_URL="https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/forward-setup.sh"
INSTALL_PATH="/usr/local/bin/forward"

echo "[*] Скачиваю forward-setup.sh..."
curl -fsSL "$REPO_RAW_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo "[+] Установлено. Теперь можно запускать командой: forward"
echo "    sudo forward            — добавить одно правило (TCP/UDP)"
echo "    sudo forward --bulk     — вставить сразу много правил"
echo "    sudo forward --flush    — очистить iptables"
