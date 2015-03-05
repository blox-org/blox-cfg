#!/usr/bin/env bash

CONFDIR=$1
OUTDIR=/usr/local/etc/opensips

if [ -z "$CONFDIR" ]
then
	echo "Usage: $0 <blox_config_dir>"
	exit -1
fi

mkdir -p $OUTDIR

for m4config in $(ls $CONFDIR/*.m4)
do
        if [ "$m4config" == "$CONFDIR/blox-define.m4" -o "$m4config" == "$CONFDIR/blox-define-nat.m4" ]
        then
                continue;
        fi
        m4 $CONFDIR/blox-define.m4 $CONFDIR/blox-define-nat.m4 $CONFDIR/blox-version.m4 $m4config > $OUTDIR/$(basename $m4config|sed 's/\.m4$//')
done

rm -f $OUTDIR/blox-tls-*.cfg
cp $CONFDIR/*.cfg $OUTDIR

if [ -n "$TRANSCODING" ]
then
	rm -f $OUTDIR/blox-lan2wan.cfg
	rm -f $OUTDIR/blox-wan2lan.cfg
	rm -f $OUTDIR/blox-allomts-dummy.cfg
else
	rm -f $OUTDIR/blox-lan2wan-allomts.cfg
	rm -f $OUTDIR/blox-wan2lan-allomts.cfg
	rm -f $OUTDIR/blox-allomts.cfg
fi

for tlsconfig in $(ls $CONFDIR/blox-tls-*.cfg)
do
	echo 'include_file "'$(basename $tlsconfig)'"' >> $OUTDIR/blox-tls.cfg 
done

#Install glob server cert
cp -avr $CONFDIR/tls/glob $OUTDIR/tls/
cat $OUTDIR/tls/rootCA/cacert.pem >> $OUTDIR/tls/glob/glob-calist.pem
