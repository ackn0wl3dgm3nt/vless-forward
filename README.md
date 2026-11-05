# vless-forward

Скрипты для настройки port-forward (DNAT) через iptables на entry-ноде — прокидывают трафик на backend-ноду (ip:port). Поддерживают VLESS (TCP) и Hysteria2 (UDP). Позволяют держать несколько туннелей на одном entry-IP, каждый на своём порту.

Есть три набора скриптов: отдельные для VLESS (TCP) и Hysteria2 (UDP), а также универсальный `forward` — TCP, UDP или оба сразу, с массовым добавлением правил. Дополнительно есть `node-tuning` — сетевой тюнинг самой entry-ноды (BBR, буферы, conntrack, MSS clamping).

## Forward (TCP + UDP, массовое добавление)

### Установка (рекомендуется)

Устанавливает скрипт в систему как команду `forward`:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/forward-install.sh | sudo bash
```

После установки:

```bash
sudo forward            # добавить одно правило (вводишь по одному)
sudo forward --bulk     # вставить сразу много правил
sudo forward --flush    # очистить iptables
```

### Использование без установки

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/forward-setup.sh -o forward-setup.sh && chmod +x forward-setup.sh && sudo ./forward-setup.sh
```

### Режим «по одному»

Скрипт спросит:

```
Entry port (на этой машине): 201
Backend (ip или ip:port, по умолчанию порт 8880): 10.0.0.5
Протокол [tcp/udp/both] (по умолчанию tcp): both
```

### Массовый режим (`--bulk`)

Запусти `sudo forward --bulk` и вставь правила списком. Пустая строка или `Ctrl+D` — конец ввода:

```
8443 1.2.3.4
9443 5.6.7.8:443
10443 9.9.9.9:8880 both
12443 1.1.1.1 tcp
1332 2.2.2.2 udp
```

Формат строки: `ENTRY_PORT BACKEND[:PORT] [tcp|udp|both]`

- Протокол по умолчанию — `tcp`, порт backend по умолчанию — `8880`.
- Можно указать диапазон входных портов: `20000-20010 1.2.3.4:8880` (все порты диапазона уходят на один backend-порт).
- Комментарии через `#` игнорируются.
- Некорректные строки пропускаются с сообщением, остальные применяются.
- Повторный запуск с теми же правилами ничего не дублирует.

Правила можно подать и из файла, не вставляя вручную:

```bash
sudo forward --bulk < rules.txt
```

## VLESS (TCP)

### Установка (рекомендуется)

Устанавливает скрипт в систему как команду `vless-forward`:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/install.sh | sudo bash
```

После установки:

```bash
sudo vless-forward
sudo vless-forward --flush
```

### Использование без установки

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh -o setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

Скрипт спросит:

```
Entry port (на этой машине): 201
Backend (ip или ip:port, по умолчанию порт 8880): 10.0.0.5
```

Если backend-порт не указан — используется `8880` по умолчанию.

## Hysteria2 (UDP)

### Установка (рекомендуется)

Устанавливает скрипт в систему как команду `hysteria2-forward`:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/hy2-install.sh | sudo bash
```

После установки:

```bash
sudo hysteria2-forward
sudo hysteria2-forward --flush
```

### Использование без установки

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/hy2-setup.sh -o hy2-setup.sh && chmod +x hy2-setup.sh && sudo ./hy2-setup.sh
```

Скрипт спросит:

```
Entry port (на этой машине, UDP): 443
Backend (ip или ip:port, по умолчанию порт 443): 10.0.0.5
```

Если backend-порт не указан — используется `443` по умолчанию.

> Через `curl | bash` без сохранения файла запускать **нельзя** — скрипты спрашивают ввод (`read`), а при пайпе stdin занят самим скриптом, ввод не пройдёт. Инсталлеры (`install.sh`, `hy2-install.sh`, `forward-install.sh`) пайпить можно — они ничего не спрашивают.

## Node tuning (тюнинг entry-ноды)

Сетевой тюнинг самой entry-ноды, чтобы снизить jitter и потери и улучшить throughput на маршрутах с плохим транзитом. Скрипт ничего не спрашивает и сам делает всё за один запуск:

- BBR + `fq`
- TCP-буферы (потолок 128MB), `tcp_mtu_probing=1`, `tcp_slow_start_after_idle=0`
- `nf_conntrack_max=65536`
- MSS clamping (`mangle/FORWARD`) с сохранением через `netfilter-persistent save`

Настройки пишутся в `/etc/sysctl.d/99-cascade-entry-tuning.conf`, модули `tcp_bbr` и `nf_conntrack` подгружаются при старте системы. Сами DNAT-правила скрипт не трогает.

Требования: `iptables` и `netfilter-persistent` (`apt install iptables iptables-persistent`).

### Запуск

Тюнинг применяется один раз на сервере, поэтому установка не нужна. Скрипт не задаёт вопросов, его можно запускать пайпом:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/node-tuning.sh | sudo bash
```

Предпросмотр без изменений:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/node-tuning.sh | sudo bash -s -- --dry-run
```

Или скачать и запустить:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/node-tuning.sh -o node-tuning.sh && chmod +x node-tuning.sh && sudo ./node-tuning.sh
```

### Особенности

- Повторный запуск безопасен: sysctl-файл перезаписывается, MSS-правило проверяется через `iptables -C` и не дублируется.
- Если `net.ipv4.ip_forward=0`, скрипт предупредит — DNAT-проброс без форвардинга не работает.
- На нодах с RAM меньше 2GB скрипт предупредит, что буферы 128MB могут быть тяжёлыми.
- `forward --flush` (и `vless-forward --flush`, `hysteria2-forward --flush`) очищает iptables целиком, включая MSS clamp. После flush запусти `node-tuning.sh` ещё раз. Настройки sysctl при этом остаются.
- Тюнинг решает пропускную способность и стабильность канала. Детектируемость и throttling протокола со стороны DPI — отдельный слой, он тюнингом не затрагивается.

## Флаг --flush

Просто очищает все iptables-правила и выходит, без вопросов про порты:

```bash
sudo forward --flush
sudo vless-forward --flush
sudo hysteria2-forward --flush
```

## Добавление ещё одного туннеля

Запусти команду снова с новым entry-портом и backend'ом — существующие правила не затрагиваются:

```bash
sudo forward
sudo forward --bulk
sudo vless-forward
sudo hysteria2-forward
```

## Проверка активных правил

```bash
sudo iptables -t nat -L PREROUTING -n --line-numbers
sudo iptables -t mangle -L FORWARD -v -n      # MSS clamp
sysctl net.ipv4.tcp_congestion_control        # bbr
```

## Обновление

Чтобы обновить установленную команду до последней версии из репозитория, просто запусти установку заново:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/forward-install.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/install.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/hy2-install.sh | sudo bash
```
