#!/bin/bash

source /etc/blox/blf.conf

prog=$(basename $0)
echo $$ > /var/run/$prog.pid

BLOX_SUBSCRIBE_HOST=$(sed -n '/divert/,/divert/p;' /etc/blox/blox-define-blf.m4 | awk '{print $0}; END{print "BLOX_SUBSCRIBE_HOST"}' | m4 -)
BLOX_SUBSCRIBE_PORT=$(sed -n '/divert/,/divert/p;' /etc/blox/blox-define-blf.m4 | awk '{print $0}; END{print "BLOX_SUBSCRIBE_PORT"}' | m4 -)

/usr/local/sbin/listen_subscribe.py $BLOX_SUBSCRIBE_HOST $BLOX_SUBSCRIBE_PORT
