#!/usr/bin/python

import socket
import sys
import re
import os
import MySQLdb
import subprocess as sub

progname = sys.argv[0] 

def usage():
	print "usage: " + progname + " <host> <port>"
	sys.exit(-1);

if len(sys.argv) < 4:
	usage


HOST = sys.argv[1]
PORT = int(sys.argv[2]) 


server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) 

try:
	server.bind((HOST, PORT))
except socket.error as msg:
	print 'Bind failed. Error Code : ' + str(msg[0]) + ' Message ' + msg[1]
	sys.exit()

db = MySQLdb.connect(host="localhost", # your host, usually localhost
                     user="opensips", # your username
                      passwd="opensipsrw", # your password
                      db="opensips_1_11") # name of the data base
cur = db.cursor(cursorclass=MySQLdb.cursors.DictCursor)

while 1:
	data, addr = server.recvfrom(1024)
	print 'Connected with ' + addr[0] + ':' + str(addr[1])
	if not data:
		break;
	else:
		data = data.strip();	
		print 'Got Data:' + data + ':' ;
		if(re.match(r"^E_SCRIPT_EVENT\s*subscribe::",data)):
			to_uri = re.sub('E_SCRIPT_EVENT\s*subscribe::','',data);
			print 'Search to_uri:' + to_uri + ':' ;
			print("SELECT from_uri, to_uri, event, socket, extra_hdr, expiry FROM blox_subscribe \
						where to_uri = '" + to_uri + "' ORDER BY last_modified DESC")
			cur.execute("SELECT from_uri, to_uri, event, socket, extra_hdr, expiry FROM blox_subscribe \
						where to_uri = '" + to_uri + "' ORDER BY last_modified DESC")
			result_blox_subscribe = cur.fetchall()
			for bsrow in result_blox_subscribe:
				bs_from_uri = bsrow['from_uri'] ;
				bs_to_uri   = bsrow['to_uri'] ;
				bs_event    = bsrow['event'] ;
				bs_expiry   = bsrow['expiry'] ;
				bs_socket   = bsrow['socket'] ;
				bs_extra_hdr = bsrow['extra_hdr'] ;
				opensipsctl_cmd = "opensipsctl fifo pua_subscribe %s %s %s %s %s '%s'" % \
						(bs_to_uri,bs_from_uri,bs_event,bs_expiry,bs_socket,bs_extra_hdr)
				print "Executing command " + opensipsctl_cmd
				p = os.popen(opensipsctl_cmd,"r")
				while 1:
				    output = p.readline()
				    if not output : break
				    print output
	
server.close()
