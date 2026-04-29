FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    asterisk \
    asterisk-modules \
    asterisk-core-sounds-en \
    asterisk-core-sounds-ru \
    asterisk-moh-opsound-wav \
    tcpdump \
    python3 \
    python3-pip \
    curl \
    wget \
    sox \
    libsox-fmt-mp3 \
    net-tools \
    iproute2 \
    && pip3 install gtts \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy configs
COPY config/sip.conf         /etc/asterisk/sip.conf
COPY config/extensions.conf  /etc/asterisk/extensions.conf
COPY config/modules.conf     /etc/asterisk/modules.conf
COPY config/rtp.conf         /etc/asterisk/rtp.conf

# Copy audio generation script and entrypoint
COPY scripts/gen_sounds.py   /usr/local/bin/gen_sounds.py
COPY scripts/entrypoint.sh   /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# Asterisk runs as asterisk user — give access to sound dir
RUN mkdir -p /var/lib/asterisk/sounds/ivr \
    && chown -R asterisk:asterisk /var/lib/asterisk/sounds/ivr \
    && chown -R asterisk:asterisk /var/log/asterisk \
    && chown -R asterisk:asterisk /var/run/asterisk

EXPOSE 5060/udp 5060/tcp 10000-10100/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]