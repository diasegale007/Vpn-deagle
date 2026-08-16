#!/bin/bash
set -e

# ===========================================
# WireGuard VPN Server Setup Script
# Тестировано на Ubuntu 20.04 / 22.04 / 24.04
# Запускать от root: sudo bash setup_wireguard.sh
# ===========================================

echo "=== WireGuard VPN Server Setup ==="

# --- Настройки (можно менять) ---
WG_INTERFACE="wg0"
WG_PORT=51820
WG_NET="10.66.66.0/24"
SERVER_IP="10.66.66.1/24"
CLIENT_IP="10.66.66.2/32"
DNS="1.1.1.1"

# Определяем внешний сетевой интерфейс автоматически
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Внешний интерфейс: $DEFAULT_IFACE"

# --- Установка WireGuard ---
apt update
apt install -y wireguard qrencode

# --- Включаем IP forwarding ---
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# --- Генерация ключей сервера ---
mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077

if [ ! -f server_private.key ]; then
    wg genkey | tee server_private.key | wg pubkey > server_public.key
fi
SERVER_PRIV=$(cat server_private.key)
SERVER_PUB=$(cat server_public.key)

# --- Генерация ключей первого клиента ---
if [ ! -f client1_private.key ]; then
    wg genkey | tee client1_private.key | wg pubkey > client1_public.key
fi
CLIENT_PRIV=$(cat client1_private.key)
CLIENT_PUB=$(cat client1_public.key)

# --- Конфиг сервера ---
cat > /etc/wireguard/${WG_INTERFACE}.conf <<EOF
[Interface]
Address = ${SERVER_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE

[Peer]
# client1
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}
EOF

# --- Запуск сервиса ---
systemctl enable wg-quick@${WG_INTERFACE}
systemctl restart wg-quick@${WG_INTERFACE}

# --- Получаем внешний IP сервера ---
SERVER_ENDPOINT_IP=$(curl -s ifconfig.me)

# --- Конфиг клиента (для приложения / телефона) ---
cat > /etc/wireguard/client1.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = 10.66.66.2/32
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${SERVER_ENDPOINT_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo ""
echo "=== Готово! ==="
echo "Сервер запущен на порту ${WG_PORT}"
echo ""
echo "Конфиг клиента сохранён: /etc/wireguard/client1.conf"
echo "Покажу его как QR-код (для быстрого импорта в WireGuard app):"
echo ""
qrencode -t ansiutf8 < /etc/wireguard/client1.conf

echo ""
echo "Проверь статус: wg show"
echo "Не забудь открыть порт ${WG_PORT}/udp в firewall/security group провайдера!"
