#!/bin/bash

# Instalasi dependensi
apt install jq curl -y

# Menyiapkan direktori
rm -rf /root/xray/scdomain
mkdir -p /root/xray

clear
echo ""
echo "Memulai konfigurasi domain..."
echo ""

# Fungsi untuk memeriksa apakah subdomain sudah ada
check_subdomain_exists() {
    local subdomain=$1
    local zone_id=$2
    local cf_id=$3
    local cf_key=$4

    local exists=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${subdomain}" \
        -H "X-Auth-Email: ${cf_id}" \
        -H "X-Auth-Key: ${cf_key}" \
        -H "Content-Type: application/json" | jq -r .result[0].id)

    if [[ "${#exists}" -gt 10 ]]; then
        return 0  # Subdomain ada
    else
        return 1  # Subdomain tidak ada
    fi
}

# Konstanta
DOMAIN="skartissh.online"
CF_ID="skartistore@gmail.com"
CF_KEY="f85902ca3abd71622dbc250f4e38afad434df"

# Mendapatkan Zone ID
ZONE=$(curl -sLX GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}&status=active" \
    -H "X-Auth-Email: ${CF_ID}" \
    -H "X-Auth-Key: ${CF_KEY}" \
    -H "Content-Type: application/json" | jq -r .result[0].id)

# Membuat subdomain acak dan memeriksa apakah sudah ada
while true; do
    sub=$(</dev/urandom tr -dc a-z0-9 | head -c3)
    SUB_DOMAIN="${sub}.${DOMAIN}"
    
    if check_subdomain_exists "${SUB_DOMAIN}" "${ZONE}" "${CF_ID}" "${CF_KEY}"; then
        echo "Subdomain ${SUB_DOMAIN} sudah ada. Membuat subdomain baru..."
    else
        break
    fi
done

set -euo pipefail

# Mendapatkan IP publik
IP=$(curl -sS ifconfig.me)

echo "Memperbarui DNS untuk ${SUB_DOMAIN}..."

# Membuat record DNS
RECORD=$(curl -sLX POST "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
    -H "X-Auth-Email: ${CF_ID}" \
    -H "X-Auth-Key: ${CF_KEY}" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'${SUB_DOMAIN}'","content":"'${IP}'","ttl":120,"proxied":false}' | jq -r .result.id)

# Menyimpan informasi subdomain
echo "$SUB_DOMAIN" > /root/domain
echo "$SUB_DOMAIN" > /root/scdomain
echo "$SUB_DOMAIN" > /etc/xray/domain
echo "$SUB_DOMAIN" > /etc/v2ray/domain
echo "$SUB_DOMAIN" > /etc/xray/scdomain
echo "IP=$SUB_DOMAIN" > /var/lib/kyt/ipvps.conf

# Membersihkan file sementara
rm -rf cf
sleep 1

echo "Konfigurasi domain selesai."
