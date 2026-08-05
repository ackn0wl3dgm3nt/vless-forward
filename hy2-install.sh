#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

REPO_RAW_URL="https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/hy2-setup.sh"
INSTALL_PATH="/usr/local/bin/hy2-forward"

echo "[*] Скачиваю hy2-setup.sh..."
curl -fsSL "$REPO_RAW_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo "[+] Установлено. Теперь можно запускать командой: hy2-forward"
echo "    sudo hy2-forward            — добавить туннель (UDP)"
echo "    sudo hy2-forward --flush    — очистить iptables"
