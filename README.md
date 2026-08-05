# vless-forward

Скрипт для настройки port-forward (DNAT) через iptables — прокидывает entry-порт на backend-ноду (ip:port). Позволяет держать несколько туннелей на одном entry-IP, каждый на своём порту.

## Установка (рекомендуется)

Устанавливает скрипт в систему как команду `vless-forward`:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/install.sh | sudo bash
```

После установки просто запускай:

```bash
sudo vless-forward
```

## Использование без установки

Скачать и запустить напрямую:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh -o setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

> Через `curl | bash` без сохранения файла запускать **нельзя** — скрипт спрашивает ввод (`read`), а при пайпе stdin занят самим скриптом, ввод не пройдёт.

Скрипт спросит:

```
Entry port (на этой машине): 201
Backend (ip или ip:port, по умолчанию порт 8880): 10.0.0.5
```

Если backend-порт не указан — используется `8880` по умолчанию.

## Флаги

- `--flush` — очистить все iptables-правила перед добавлением нового туннеля:

```bash
sudo vless-forward --flush
```

## Добавление ещё одного туннеля

Просто запусти команду снова с новым entry-портом и backend'ом — существующие правила не затрагиваются:

```bash
sudo vless-forward
```

## Проверка активных правил

```bash
sudo iptables -t nat -L PREROUTING -n --line-numbers
```

## Обновление

Чтобы обновить установленную команду до последней версии из репозитория:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/install.sh | sudo bash
```
