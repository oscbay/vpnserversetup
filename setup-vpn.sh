#!/bin/bash

# ==============================
# OpenVPN TCP 443 setup with username/password for Windows
# ==============================

VPN_USER="vpnuser"
VPN_PASS="password"
VPN_HOST="oscarbaylisvpn.tplinkdns.com"

echo "[*] Updating system..."
apt update && apt upgrade -y
apt install -y openvpn easy-rsa ufw

echo "[*] Setting up PKI..."
make-cadir ~/openvpn-ca
cd ~/openvpn-ca || exit

cat > vars <<EOF
set_var EASYRSA_REQ_COUNTRY    "NZ"
set_var EASYRSA_REQ_PROVINCE   "Taranaki"
set_var EASYRSA_REQ_CITY       "New Plymouth"
set_var EASYRSA_REQ_ORG        "VPNServer"
set_var EASYRSA_REQ_EMAIL      "admin@$VPN_HOST"
set_var EASYRSA_REQ_OU         "VPN"
EOF

./easyrsa init-pki
echo -e "\n" | ./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
./easyrsa gen-dh
openvpn --genkey --secret ta.key

mkdir -p /etc/openvpn/server
cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem ta.key /etc/openvpn/server/

echo "[*] Creating server config..."
cat >/etc/openvpn/server/server.conf <<EOF
port 443
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
auth SHA256
topology subnet
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

echo "[*] Enabling IP forwarding..."
sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p

echo "[*] Setting firewall rules..."
ufw allow 443/tcp
ufw enable
ufw status

echo "[*] Starting OpenVPN..."
systemctl enable openvpn@server
systemctl start openvpn@server

echo "[*] Generating client config..."
mkdir -p ~/client-configs/files
cat > ~/client-configs/base.conf <<EOF
client
dev tun
proto tcp
remote $VPN_HOST 443
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-256-CBC
auth-user-pass
key-direction 1
verb 3
EOF

echo "[*] Setup complete."
echo "You can now create Windows client .ovpn files using the base.conf and your username/password."
