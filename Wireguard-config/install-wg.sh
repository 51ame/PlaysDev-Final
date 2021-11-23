#!/bin/bash

# Обновить список доступных пакетов и сами пакеты
sudo apt update && sudo apt upgrade -y
# Настройка пересылки трафика
sudo sed -i 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo sysctl -p
# Установка Wireguard
sudo apt install wireguard -y
# Установка qrencode
sudo apt install qrencode -y
# Генерируем ключи
sudo chown $USER:$USER /etc/wireguard/
cd /etc/wireguard
wg genkey | tee server_privatekey | wg pubkey > server_publickey
wg genkey | tee client_privatekey | wg pubkey > client_publickey
# Задаем Env. variables
read SRV_PRIV < ./server_privatekey
read SRV_PUB < ./server_publickey
read CLIENT_PRIV < ./client_privatekey
read CLIENT_PUB < ./client_publickey
WIREGUARD_EIP=$(aws ec2 describe-instances   --filter "Name=instance-state-name,Values=running"   --query "Reservations[*].Instances[*].[PublicIpAddress, Tags[?Key=='Name'].Value|[0]]"   --output text | grep Wireguard | awk '{print $1}')
WIREGUARD_PORT="61253"
WIREGUARD_ENDPOINT=$WIREGUARD_EIP:$WIREGUARD_PORT
# Создаем конфиг сервера
sudo cat >> /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = $WIREGUARD_PORT
PrivateKey = $SRV_PRIV
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = 10.0.0.2/32
EOF
# Запустим сервис
sudo wg-quick up wg0
# Добавляем сервис в автозапуск (опционально)
sudo systemctl enable wg-quick@wg0.service
# Создаем конфиг клиента
sudo cat >> /etc/wireguard/client.conf << EOF
[Interface]
Address = 10.0.0.2/32
PrivateKey = $CLIENT_PRIV
DNS = 8.8.8.8, 8.8.4.4
[Peer]
PublicKey = $SRV_PUB
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $WIREGUARD_ENDPOINT
EOF
# Выводим QR код
# qrencode -t ansiutf8 < /etc/wireguard/client.conf