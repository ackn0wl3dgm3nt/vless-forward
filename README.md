# vless-forward

Скрипт для настройки port-forward (DNAT) через iptables — прокидывает entry-порт на backend-ноду (ip:port). Позволяет держать несколько туннелей на одном entry-IP, каждый на своём порту.

## Использование

Скачать и запустить напрямую с GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh -o setup.sh && chmod +x setup.sh && sudo ./setup.sh
```

Или в одну строку без сохранения файла:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh | sudo bash
```

Скрипт спросит:

```
Entry port (на этой машине): 201
Backend (ip или ip:port, по умолчанию порт 8880): 10.0.0.5
```

Если backend-порт не указан — используется `8880` по умолчанию.

## Флаги

- `--flush` — очистить все iptables-правила перед добавлением нового туннеля:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh | sudo bash -s -- --flush
```

## Добавление ещё одного туннеля

Просто запустите скрипт снова с новым entry-портом и backend'ом — существующие правила не затрагиваются:

```bash
curl -fsSL https://raw.githubusercontent.com/ackn0wl3dgm3nt/vless-forward/main/setup.sh | sudo bash
```

## Проверка активных правил

```bash
sudo iptables -t nat -L PREROUTING -n --line-numbers
```
