#!/usr/bin/env bash
#
# node-tuning.sh — тюнинг ENTRY-ноды (DNAT proxy) cascade-схемы.
#
# Делает:
#   1. BBR + fq
#   2. TCP-буферы (128MB потолок), mtu_probing, slow_start_after_idle=0
#   3. conntrack_max=65536
#   4. MSS clamping (mangle/FORWARD) + netfilter-persistent save
#
# Проброс портов (DNAT/MASQUERADE/FORWARD) НЕ трогает — он настраивается
# отдельной ansible-ролью и должен уже существовать.
#
# Скрипт идемпотентен: повторный запуск не плодит дубликаты.
# Использование:  sudo ./node-tuning.sh [--dry-run]

set -euo pipefail

SYSCTL_FILE="/etc/sysctl.d/99-cascade-entry-tuning.conf"
MODULES_FILE="/etc/modules-load.d/cascade-entry-tuning.conf"
CONNTRACK_MAX=65536
DRY_RUN=0

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log()  { echo -e "\e[32m[+]\e[0m $*"; }
warn() { echo -e "\e[33m[!]\e[0m $*" >&2; }
die()  { echo -e "\e[31m[x]\e[0m $*" >&2; exit 1; }

run() {
    if (( DRY_RUN )); then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

# --- Проверки ---------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "Запускай от root (sudo ./node-tuning.sh)"

command -v iptables >/dev/null 2>&1 \
    || die "iptables не установлен (apt install iptables)"
command -v netfilter-persistent >/dev/null 2>&1 \
    || die "netfilter-persistent не установлен (apt install iptables-persistent)"

(( DRY_RUN )) && warn "Режим dry-run: изменения не применяются"

# --- 1. Модули ядра ---------------------------------------------------------
log "Загрузка модулей tcp_bbr и nf_conntrack"
run modprobe tcp_bbr || die "Ядро не поддерживает tcp_bbr"
run modprobe nf_conntrack || warn "Не удалось загрузить nf_conntrack"

log "Автозагрузка модулей при старте системы: $MODULES_FILE"
if (( ! DRY_RUN )); then
    cat > "$MODULES_FILE" << 'EOF'
tcp_bbr
nf_conntrack
EOF
fi

# --- 2-4. sysctl ------------------------------------------------------------
log "Запись sysctl-настроек: $SYSCTL_FILE"
if (( ! DRY_RUN )); then
    cat > "$SYSCTL_FILE" << EOF
# Cascade ENTRY node tuning (managed by node-tuning.sh)

# BBR + qdisc
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP буферы
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0

# Conntrack
net.netfilter.nf_conntrack_max=${CONNTRACK_MAX}
EOF
fi

log "Применение sysctl"
run sysctl --system >/dev/null

# --- 5. MSS clamping --------------------------------------------------------
MSS_RULE=(-p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu)

if iptables -t mangle -C FORWARD "${MSS_RULE[@]}" 2>/dev/null; then
    log "MSS clamp уже есть в mangle/FORWARD — пропускаю"
else
    log "Добавляю MSS clamp в mangle/FORWARD"
    run iptables -t mangle -A FORWARD "${MSS_RULE[@]}"
fi

log "Сохранение правил iptables (netfilter-persistent save)"
run netfilter-persistent save >/dev/null

# --- Предупреждение про форвардинг -----------------------------------------
if [[ "$(sysctl -n net.ipv4.ip_forward)" != "1" ]]; then
    warn "net.ipv4.ip_forward=0 — DNAT-проброс работать не будет! Проверь ansible-роль проброса."
fi

# --- Проверка результата ----------------------------------------------------
echo
log "Итог:"
printf '  %-45s %s\n' "tcp_congestion_control:" "$(sysctl -n net.ipv4.tcp_congestion_control)"
printf '  %-45s %s\n' "default_qdisc:"          "$(sysctl -n net.core.default_qdisc)"
printf '  %-45s %s\n' "rmem_max:"               "$(sysctl -n net.core.rmem_max)"
printf '  %-45s %s\n' "wmem_max:"               "$(sysctl -n net.core.wmem_max)"
printf '  %-45s %s\n' "tcp_mtu_probing:"        "$(sysctl -n net.ipv4.tcp_mtu_probing)"
printf '  %-45s %s\n' "tcp_slow_start_after_idle:" "$(sysctl -n net.ipv4.tcp_slow_start_after_idle)"
printf '  %-45s %s\n' "nf_conntrack_max:"       "$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null || echo n/a)"
printf '  %-45s %s\n' "nf_conntrack_count:"     "$(sysctl -n net.netfilter.nf_conntrack_count 2>/dev/null || echo n/a)"
echo
log "MSS clamp в цепочке:"
iptables -t mangle -L FORWARD -v -n | grep -E 'TCPMSS|^Chain' || true

mem_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if (( mem_mb < 2048 )); then
    warn "RAM ${mem_mb}MB (<2GB): буферы 128MB могут кусаться, следи за free -h"
fi

log "Готово."
