SYSARCH?=64
ifeq ($(SYSARCH),32)
SYSARCH=
endif
STAGEDIR=bin$(SYSARCH)

EXE=inotify-recursive
CFLAGS=-g -O2

.PHONY:
all: init $(EXE)

.PHONY:
init:
	mkdir -p $(STAGEDIR)

inotify-recursive: inotify-recursive.c
	$(CC) $(CFLAGS) $< -o $(STAGEDIR)/$@

install:
	-@mkdir -p $(BASEDIR)/usr/bin 
	cp -avr ${STAGEDIR}/* $(BASEDIR)/usr/bin

clean:
	rm -fr $(STAGEDIR)
