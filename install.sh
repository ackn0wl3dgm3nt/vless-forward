#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

REPO_RAW_URL="https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh"
INSTALL_PATH="/usr/local/bin/vless-forward"

echo "[*] Скачиваю setup.sh..."
curl -fsSL "$REPO_RAW_URL" -o "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo "[+] Установлено. Теперь можно запускать командой: vless-forward"
echo "    Флаг --flush тоже работает: vless-forward --flush"
