#!/bin/bash

prog=$(basename $0)
echo $$ > /var/run/$prog.pid

BLOX_NOTIFY_HOST=$(sed -n '/divert/,/divert/p;' /etc/blox/blox-define-presence.m4 | awk '{print $0}; END{print "BLOX_NOTIFY_HOST"}' | m4 -)
BLOX_NOTIFY_PORT=$(sed -n '/divert/,/divert/p;' /etc/blox/blox-define-presence.m4 | awk '{print $0}; END{print "BLOX_NOTIFY_PORT"}' | m4 -)

/usr/bin/inotify-recursive /var/log/blox-notify | 
while read line;  
do 
if [[ $line =~ ^CREATED\ FILE ]]; then 
	filename=$(echo $line | awk '{print $3}'); 
	echo $filename; 
	/usr/local/sbin/send_notify.py $BLOX_NOTIFY_HOST $BLOX_NOTIFY_PORT $filename; 
	echo "Removing the file $filename"
	rm -f $filename
fi 
done

