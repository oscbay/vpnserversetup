#!/bin/bash

# ==============================
# Simple StrongSwan IKEv2 VPN on UDP 443 with username/password for Windows
# ==============================

VPN_USER="vpnuser"
VPN_PASS="vpnpassword123"
VPN_HOST="oscarbaylisvpn.tplinkdns.com"

echo "[*] Updating system..."
apt update && apt upgrade -y
apt install -y strongswan strongswan-pki libcharon-extra-plugins ufw

echo "[*] Configuring StrongSwan..."

# ipsec.conf
cat >/etc/ipsec.conf <<EOF
config setup
    uniqueids=never

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@$VPN_HOST
    leftcert=server-cert.pem
    leftsendcert=never
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightsendcert=never
    eap_identity=%identity
EOF

# ipsec.secrets
cat >/etc/ipsec.secrets <<EOF
$VPN_USER : EAP "$VPN_PASS"
EOF

echo "[*] Configuring StrongSwan to use UDP 443"
cat >/etc/strongswan.d/charon.conf <<EOF
charon {
    plugins {
        socket-default {
            ike_port = 443
            nat_t_port = 443
        }
    }
}
EOF

echo "[*] Setting firewall rules..."
ufw allow 443/udp
ufw delete allow 500/udp || true
ufw delete allow 4500/udp || true

echo "[*] Restarting StrongSwan..."
systemctl restart strongswan-starter

echo "[*] Setup complete."
echo "Connect from Windows using IKEv2 VPN at $VPN_HOST with username '$VPN_USER'."
