#!/bin/bash
set -e

echo "============================================"
echo " Asterisk IVR Docker — Startup"
echo "============================================"

sed -i "s/__PASSWORD_1001__/${SIP_PASSWORD_1001}/g" /etc/asterisk/sip.conf
sed -i "s/__PASSWORD_1002__/${SIP_PASSWORD_1002}/g" /etc/asterisk/sip.conf
sed -i "s/__PASSWORD_1003__/${SIP_PASSWORD_1003}/g" /etc/asterisk/sip.conf

# 1. Detect and patch external IP
echo "[1/6] Detecting external IP..."
EXTERNAL_IP=$(curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://ifconfig.me)

if [ -z "${EXTERNAL_IP}" ]; then
    echo "   WARNING: Could not detect external IP, keeping existing value"
else
    echo "   External IP: ${EXTERNAL_IP}"
    sed -i "s/^externip=.*/externip=${EXTERNAL_IP}/" /etc/asterisk/sip.conf
fi

# 2. Fix EC2 hostname resolution warning (harmless but noisy)
echo "[2/6] Patching /etc/hosts for EC2 hostname..."
HOSTNAME=$(hostname)
if ! grep -q "${HOSTNAME}" /etc/hosts; then
    echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
    echo "   Added: 127.0.0.1 ${HOSTNAME}"
else
    echo "   Already present, skipping."
fi

# 3. Generate TTS audio files (beep is generated via sox in gen_sounds.py)
echo "[3/6] Generating IVR audio files..."
python3 /usr/local/bin/gen_sounds.py

# Fix ownership after generation
chown -R asterisk:asterisk /usr/share/asterisk/sounds/ivr

# 4. Start tcpdump in background
echo "[4/6] Starting tcpdump (SIP capture → /var/log/asterisk/sip_capture.pcap)..."
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
IFACE=${IFACE:-eth0}

tcpdump -i "${IFACE}" \
    -w /var/log/asterisk/sip_capture.pcap \
    -s 0 \
    port 5060 or portrange 10000-10100 \
    &
TCPDUMP_PID=$!
echo "   tcpdump PID: ${TCPDUMP_PID} on interface ${IFACE}"

# 5. Set permissions
echo "[5/6] Fixing permissions..."
mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk

# 6. Launch Asterisk
echo "[6/6] Starting Asterisk..."
echo "   Dial 100 to reach the IVR menu."
echo "   SIP accounts: 1001, 1002, 1003  (password: secret123)"
echo "============================================"

# Trap signals to cleanly stop tcpdump
cleanup() {
    echo "Stopping tcpdump..."
    kill "${TCPDUMP_PID}" 2>/dev/null || true
    echo "PCAP saved to /var/log/asterisk/sip_capture.pcap"
}
trap cleanup EXIT

# Run Asterisk in foreground
exec asterisk -fvvvg