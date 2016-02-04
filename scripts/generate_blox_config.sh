#!/usr/bin/env bash

CONFDIR=$1
OUTDIR=/usr/local/etc/opensips

#Functions
IsModuleEnabled() {
	MODNAME=$1
	CONTEXT=modules
	CONFIGFILE=$CONFDIR/blox.conf
	
	if [ -z "$MODNAME" ]
	then
	   echo no
	else
	sed -e 's/[[:space:]]*\=[[:space:]]*/=/g' \
	 -e 's/;.*$//' \
	 -e 's/[[:space:]]*$//' \
	 -e 's/^[[:space:]]*//' \
	 -e "s/^\(.*\)=\([^\"']*\)$/\1=\2/" \
	< $CONFIGFILE \
	| sed -n -e "/^\[$CONTEXT\]/,/^\s*\[/{/^[^;].*\=.*/p;}" | awk -v MODNAME=$MODNAME -F= '{if($1==MODNAME) print $2; }'
	fi
}

#Humbug Configuration
HumbugConfig() 
{
	MODNAME=humbug
	ModEnabled=$(IsModuleEnabled $MODNAME)
	if [ "$ModEnabled" == "yes" ]
	then
	    echo "Module $MODNAME is required";
	else
	    echo "Module is $MODNAME not required";
	    rm -f $OUTDIR/blox-humbug.cfg
	    rm -f $OUTDIR/blox-humbug-invite.cfg
	fi
}


if [ -z "$CONFDIR" ]
then
	echo "Usage: $0 <blox_config_dir>"
	exit -1
fi

mkdir -p $OUTDIR

IGNORE_m4=("$CONFDIR/blox-ua.m4" "$CONFDIR/blox-define.m4" "$CONFDIR/blox-define-nat.m4" "$CONFDIR/blox-humbug.m4" "$CONFDIR/blox-codec.m4" "$CONFDIR/blox-define-presence.m4")
M4_FILES="$CONFDIR/blox-mpath.m4 $CONFDIR/blox-ua.m4 $CONFDIR/blox-define.m4 $CONFDIR/blox-define-nat.m4 $CONFDIR/blox-version.m4 $CONFDIR/blox-humbug.m4 $CONFDIR/blox-codec.m4 $CONFDIR/blox-define-presence.m4"

for m4config in $(ls $CONFDIR/*.m4)
do
        b4IGNORE_m4=(${IGNORE_m4[@]})
        IGNORE_m4=(${IGNORE_m4[@]/$m4config})
        #echo ${#b4IGNORE_m4[*]} -ne ${#IGNORE_m4[*]}
        if [ ${#b4IGNORE_m4[*]} -ne ${#IGNORE_m4[*]} ]
        then
                echo "Ignoring $m4config";
                continue;
        fi
        m4 $M4_FILES $m4config > $OUTDIR/$(basename $m4config|sed 's/\.m4$//')
done

rm -f $OUTDIR/blox-tls-*.cfg
cp $CONFDIR/*.cfg $OUTDIR

cat $OUTDIR/regex-groups.cfg >> $OUTDIR/regex-groups-all.cfg

if [ -n "$TRANSCODING" ]
then
	rm -f $OUTDIR/blox-allomts-dummy.cfg
else
	rm -f $OUTDIR/blox-allomts.cfg
fi

#TLS Configuration
for tlsconfig in $(ls $CONFDIR/blox-tls-*.cfg)
do
	echo 'include_file "'$(basename $tlsconfig)'"' >> $OUTDIR/blox-tls.cfg 
done

#Install glob server cert
cp -avr $CONFDIR/tls/glob $OUTDIR/tls/
cat $OUTDIR/tls/rootCA/cacert.pem >> $OUTDIR/tls/glob/glob-calist.pem

#Module configuration
HumbugConfig
