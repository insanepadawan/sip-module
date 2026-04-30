#!/bin/bash
set -e

echo "============================================"
echo " Asterisk IVR Docker — Startup"
echo "============================================"

echo "[1/4] Detecting external IP..."
EXTERNAL_IP=$(curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://ifconfig.me)

if [ -z "${EXTERNAL_IP}" ]; then
    echo "   WARNING: Could not detect external IP, keeping existing value"
else
    echo "   External IP: ${EXTERNAL_IP}"
    sed -i "s/^externip=.*/externip=${EXTERNAL_IP}/" /etc/asterisk/sip.conf
fi

# 2. Generate TTS audio files
echo "[2/5] Generating IVR audio files..."
python3 /usr/local/bin/gen_sounds.py

# Fix ownership after generation (runs as root in container)
chown -R asterisk:asterisk /var/lib/asterisk/sounds/ivr

# 3. Start tcpdump in background (SIP only, port 5060)
echo "[3/5] Starting tcpdump (SIP capture → /var/log/asterisk/sip_capture.pcap)..."
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
IFACE=${IFACE:-eth0}

tcpdump -i "${IFACE}" \
    -w /var/log/asterisk/sip_capture.pcap \
    -s 0 \
    port 5060 or portrange 10000-10100 \
    &
TCPDUMP_PID=$!
echo "   tcpdump PID: ${TCPDUMP_PID} on interface ${IFACE}"

# 4. Set permissions
echo "[4/5] Fixing permissions..."
mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk

# 5. Launch Asterisk
echo "[5/5] Starting Asterisk..."
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