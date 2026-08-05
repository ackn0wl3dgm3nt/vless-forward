# vless-forward

Скрипты для настройки port-forward (DNAT) через iptables на entry-ноде — прокидывают трафик на backend-ноду (ip:port). Поддерживают VLESS (TCP) и Hysteria2 (UDP). Позволяют держать несколько туннелей на одном entry-IP, каждый на своём порту.

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

> Через `curl | bash` без сохранения файла запускать **нельзя** — скрипты спрашивают ввод (`read`), а при пайпе stdin занят самим скриптом, ввод не пройдёт. Инсталлеры (`install.sh`, `hy2-install.sh`) пайпить можно — они ничего не спрашивают.

## Флаг --flush

Просто очищает все iptables-правила и выходит, без вопросов про порты:

```bash
sudo vless-forward --flush
sudo hysteria2-forward --flush
```

## Добавление ещё одного туннеля

Запусти команду снова с новым entry-портом и backend'ом — существующие правила не затрагиваются:

```bash
sudo vless-forward
sudo hysteria2-forward
```

## Проверка активных правил

```bash
sudo iptables -t nat -L PREROUTING -n --line-numbers
```

## Обновление

Чтобы обновить установленную команду до последней версии из репозитория, просто запусти установку заново:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/install.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/hy2-install.sh | sudo bash
```
