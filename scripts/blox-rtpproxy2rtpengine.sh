#!/bin/bash

OPENSIPS_MODPARAM_RTPENGINE=/usr/local/etc/opensips/blox-modparam-rtpengine.cfg
PORT_OFFSET=4
START_PORT=$((2222-PORT_OFFSET))
NG_PORT=$START_PORT

rm -f $OPENSIPS_MODPARAM_RTPENGINE
for rtpproxyconfig in /etc/rtpproxy/*
do

source $rtpproxyconfig

INTERNAL_IP=$(ip addr show $INTERNAL_INTERFACE | grep "scope global $INTERNAL_INTERFACE$" | sed 's|.*inet \(.*\)/.*|\1|')
EXTERNAL_IP=$(ip addr show $EXTERNAL_INTERFACE | grep "scope global $EXTERNAL_INTERFACE$" | sed 's|.*inet \(.*\)/.*|\1|')

NG_PORT=$((NG_PORT+PORT_OFFSET))
NG_CLI_PORT=$((NG_PORT+1))

cat > /etc/rtpengine/$PROFILE_NAME.conf<<EOF
KERNEL=yes
TABLE=$PROFILE_ID
FALLBACK=no
RTP_IP[0]=internal/$INTERNAL_IP
RTP_IP[1]=external/$EXTERNAL_IP
LISTEN_NG=127.0.0.1:$NG_PORT
LISTEN_CLI=127.0.0.1:$NG_CLI_PORT
PORT_MIN=$RTPPORT_START
PORT_MAX=$RTPPORT_END
EOF

echo "modparam(\"rtpengine\", \"rtpengine_sock\", \"$PROFILE_ID == udp:127.0.0.1:$NG_PORT\")" >> $OPENSIPS_MODPARAM_RTPENGINE

done
