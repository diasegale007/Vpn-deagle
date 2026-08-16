# VPN App — Flutter клиент + бэкенд

## Что уже сделано

1. **`setup_wireguard.sh`** — скрипт, поднимающий WireGuard VPN-сервер на VPS (Ubuntu). Отдаёт ключи сервера и клиента.
2. **`vpn_backend/`** — Node.js/Express сервер, который раздаёт список VPN-серверов и их конфиги приложению (`GET /api/servers`).
3. **`vpn_app/`** (эта папка) — Flutter-приложение: список серверов, экран подключения, обёртка над WireGuard через `wireguard_flutter`.

## Как запустить

### 1. Поднять хотя бы один VPN-сервер
```bash
scp setup_wireguard.sh root@YOUR_VPS_IP:~
ssh root@YOUR_VPS_IP
sudo bash setup_wireguard.sh
```
Скрипт выведет `server_public.key`, `client1_private.key` и IP сервера — это то, что нужно вписать в `vpn_backend/servers.json`.

### 2. Заполнить servers.json
Открой `vpn_backend/servers.json` и подставь реальные значения:
- `endpoint` → IP сервера + `:51820`
- `serverPublicKey` → содержимое `/etc/wireguard/server_public.key`
- `clientPrivateKey` → содержимое `/etc/wireguard/client1_private.key`

Добавь ещё объектов в массив — по одному на каждый VPN-сервер (нужно повторить шаг 1 на других VPS).

### 3. Запустить бэкенд
```bash
cd vpn_backend
npm install
npm start
```
Проверить: открыть `http://localhost:3000/api/servers` — должен вернуться JSON со списком серверов.

Для реального использования бэкенд нужно задеплоить (Render, Railway, свой VPS) и обновить `baseUrl` в `lib/services/api_service.dart`.

### 4. Запустить Flutter-приложение
```bash
cd vpn_app
flutter pub get
flutter run
```

**iOS**: дополнительно нужно в Xcode добавить Network Extension target (это требование Apple для любых VPN-приложений, не специфика этого кода) — плагин `wireguard_flutter` даёт инструкцию в своём README.

**Android**: должно заработать из коробки, плагин сам запрашивает разрешение VpnService при первом подключении.

## Авторизация и персональные ключи (добавлено)

- `POST /api/auth/register`, `POST /api/auth/login` — выдают JWT-токен.
- `GET /api/servers` — публичный список серверов без ключей.
- `POST /api/servers/:id/connect` (нужен `Authorization: Bearer <token>`) — генерирует
  персональную пару WireGuard-ключей пользователя (если её ещё нет), добавляет peer
  на реальный VPN-сервер по SSH (`wg set wg0 peer ... allowed-ips ...`) и возвращает
  готовый конфиг для подключения. Требует `user.subscriptionActive == true` — иначе 403.

### Настройка SSH-доступа бэкенда к VPN-серверам
В `vpn_backend/servers.json` для каждого сервера укажи:
- `sshHost`, `sshUser` (обычно `root`), `sshKeyPath` — путь к приватному SSH-ключу
  на машине, где крутится бэкенд (не путать с WireGuard-ключами)
- `subnetPrefix` (например `10.66.66`) и `nextClientOffset` — с какого IP в подсети
  начинать выдавать адреса пользователям

Бэкенду также нужен установленный `wireguard-tools` (`apt install wireguard-tools`)
для команды `wg genkey`/`wg pubkey`, используемой при генерации ключей.

### Подписка
Поле `subscriptionActive` сейчас выставляется вручную в `vpn_backend/db/db.json`
(файловая БД на основе lowdb). Для реальной монетизации нужно подключить
платёжного провайдера (Stripe / RevenueCat / App Store & Google Play In-App Purchases)
и по вебхуку обновлять это поле.

## Важно перед публикацией в сторы

- Замени `JWT_SECRET` в `routes/authMiddleware.js` на случайную строку через переменную окружения.
- **Google Play / App Store** отдельно проверяют VPN-приложения — потребуется явно объяснить, зачем нужен доступ к трафику, и пройти доп. ревью.
- `db.json` — файловая БД для примера; для продакшена замени на PostgreSQL/MongoDB.
