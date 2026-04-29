#!/bin/bash
set -e

echo "============================================"
echo " Asterisk IVR Docker — Startup"
echo "============================================"

# 1. Generate TTS audio files
echo "[1/4] Generating IVR audio files..."
python3 /usr/local/bin/gen_sounds.py

# Fix ownership after generation (runs as root in container)
chown -R asterisk:asterisk /var/lib/asterisk/sounds/ivr

# 2. Start tcpdump in background (SIP only, port 5060)
echo "[2/4] Starting tcpdump (SIP capture → /var/log/asterisk/sip_capture.pcap)..."
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
IFACE=${IFACE:-eth0}

tcpdump -i "${IFACE}" \
    -w /var/log/asterisk/sip_capture.pcap \
    -s 0 \
    port 5060 or portrange 10000-10100 \
    &
TCPDUMP_PID=$!
echo "   tcpdump PID: ${TCPDUMP_PID} on interface ${IFACE}"

# 3. Set permissions
echo "[3/4] Fixing permissions..."
mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk

# 4. Launch Asterisk
echo "[4/4] Starting Asterisk..."
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