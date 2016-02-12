#!/usr/bin/python

import sys
import MySQLdb
import re
import urlparse
import socket
import os.path


def usage():
	print "usage: " + progname + " <host> <port> <notify file>"
	sys.exit(-1);


progname = sys.argv[0] 

if len(sys.argv) < 4 :
	usage

HOST = sys.argv[1] 
PORT = int(sys.argv[2]) 
notify_file = sys.argv[3]

def send_to_server(filename):
	clientsocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	clientsocket.connect((HOST, PORT))
	with open(filename, 'r') as content_file:
		content = content_file.read()
	clientsocket.send(content)
	nfd.close()
	clientsocket.close() ;

def print_filecontent(filename):
	with open(filename, 'r') as content_file:
		content = content_file.read()
	print content 

def parse_uri(uri):
	uri = uri.strip();
	o = urlparse.urlparse(uri);
	transport = "" ;
	for t in o.params.split(";"):
		if(re.match("transport",t)):
			transport = t
			break

	uri = re.sub(r'^sip:','',uri);

	if re.search(r'@',uri):
		return dict([ ('user', re.sub(r'(.*)@.*',r'\1',o.path)) , \
		 ('ip',   re.sub(r'.*@(.*):.*',r'\1',o.path)) if re.match(r'.*@.*:.*',o.path) else ('ip', re.sub(r'.*@(.*)',r'\1',o.path)), \
		 ('port', re.sub(r'.*@.*:(.*)',r'\1',o.path)) if re.match(r'.*@.*:.*',o.path) else ('port', "5060"), \
		 ('transport', re.sub(r'.*transport=(.*)',r'\1',transport))])
	else:
		return dict([ ('user', "") , \
		 ('ip',   re.sub(r'(.*):.*',r'\1',o.path)) if re.match(r'.*:.*',o.path) else ('ip', re.sub(r'(.*)',r'\1',o.path)), \
		 ('port', re.sub(r'.*:(.*)',r'\1',o.path)) if re.match(r'.*:.*',o.path) else ('port', "5060"), \
		 ('transport', re.sub(r'.*transport=(.*)',r'\1',transport))])
		

def send_notify(lprow,wturi,furi,touri):
	#print lprow.keys()
	nfd = open(notify_file,"r",1);
	recvline = nfd.readline(); #Ignore this customized line
	localsocket = lprow['socket'].split(':');
	content_length=0
	contact = lprow['contact'].split('@') ;
	replace_watcher_uri = contact[0] + '@' + localsocket[1] + ':' + localsocket[2] ;
	replace_to_uri   = 'sip:' + lprow['username'] + '@' + localsocket[1] + ':' + localsocket[2] ;
	replace_from_uri = 'sip:' + lprow['username'] + '@' + localsocket[1] + ':' + localsocket[2] ;
	furi_defport  = furi ;
	touri_defport = touri ;
	wturi_defport = wturi ;

	notify_file_out = "/var/tmp/" + replace_from_uri + ".out"
	nfd_w = open(notify_file_out,"w",1);

	#print len(touri.split(':'))
	if len(wturi.split(':'))<=2: #First add default 5060 for substution
		wturi_defport = wturi + ':5060' ;
	wturi = re.sub(':5060','',wturi); #Remove 5060 for substution
	if len(touri.split(':'))<=2: #First add default 5060 for substution
		touri_defport = touri + ':5060' ;
	touri = re.sub(':5060','',touri); #Remove 5060 for substution
	if len(furi.split(':'))<=2:  #First add default 5060 for substution
		furi_defport = furi + ':5060' ;
	furi = re.sub(':5060','',furi); #Remove 5060 for substution

	print 'from_uri:' + furi_defport  + '===' +  furi  + "==" + replace_from_uri;
	print 'to_uri:'   + touri_defport + '===' +  touri + "==" + replace_to_uri;
	print 'wt_uri:'   + wturi_defport + '===' +  wturi + "==" + replace_watcher_uri;
	for line in nfd:
		if re.match(r'Via:',line,re.M|re.I):
			line = re.sub(r'Via: SIP/2.0/UDP (.*);branch=(.*)',r'Via: SIP/2.0/UDP 127.0.0.1:7777;branch=\2',line)
		elif re.match(r'To:',line,re.M|re.I):
			replace_from_pat = r'To:\1;tag='+ re.escape(lprow['attr']) + r'\3\r\n'
			line = re.sub(r'To:(.*);tag=(.*)(;*.*)\r\n',replace_from_pat,line)
		elif re.match(r'Call-ID:',line,re.M|re.I):
			line = re.sub(r'Call-ID:(.*)\r\n','Call-ID: ' + lprow['callid'] + '\r\n',line)
		elif re.match('\r\n',line,re.M|re.I):
			break ;

		(line,cnt) = re.subn(wturi_defport,replace_watcher_uri,line)
		if(cnt==0):
			line = re.sub(wturi,replace_watcher_uri,line)

		(line) = re.sub(furi_defport,replace_from_uri,line)
		if(cnt==0):
			line = re.sub(furi,replace_from_uri,line)

		(line,cnt) = re.subn(touri_defport,replace_to_uri,line)
		if(cnt==0):
			line = re.sub(touri,replace_to_uri,line)

		if re.match(r'Content-Length:',line,re.M|re.I):
			line = None ;

		if line is not None:
			nfd_w.write(line) 

	content = "" ;
	for line in nfd:
		content_length += len(line) ;
		content += line ;

	(content,cnt) = re.subn(wturi_defport,replace_watcher_uri,content)
	if(cnt==0):
		content = re.sub(wturi,replace_watcher_uri,content)

	(content,cnt) = re.subn(furi_defport,replace_from_uri,content)
	if(cnt==0):
		content = re.sub(furi,replace_from_uri,content)

	(content,cnt) = re.subn(touri_defport,replace_to_uri,content)
	if(cnt==0):
		content = re.sub(touri,replace_to_uri,content)

	nfd_w.write('Remote-Contact-Header: ' + lprow['received'] + '\r\n') ;
	nfd_w.write('Send-Socket: ' + lprow['socket'] + '\r\n') ;
	nfd_w.write('Content-Length: ' + `content_length` + "\r\n\r\n") 
	nfd_w.write(content)

	nfd.close()
	nfd_w.close()
	#print notify_file_out
	send_to_server(notify_file_out)
	#print_filecontent(notify_file_out)



#MAIN()
nfd = open(notify_file,"r",1);
recvline = nfd.readline();
reqline = nfd.readline().split()
if reqline[0] == "NOTIFY":
	print recvline
	print reqline[0]
else:
	print "Error: Not NOTIFY"
	print recvline
	print reqline[0]
	nfd.close();
	sys.exit(-1) ;

for line in nfd:
	if re.match(r'From:',line,re.M|re.I):
		from_uri = re.sub(r'From:\s*(.*)',r'\1',line.split(';')[0])
		break;
nfd.close() ;

watcher_uri = reqline[1] ;
#watcher = parse_uri(watcher_uri);

db = MySQLdb.connect(host="localhost", # your host, usually localhost
                     user="opensips", # your username
                      passwd="opensipsrw", # your password
                      db="opensips_1_11") # name of the data base


cur = db.cursor(cursorclass=MySQLdb.cursors.DictCursor)

print "SELECT value FROM blox_profile_config where uuid = '" + recvline.strip() + "'"; #Get LAN Profile
cur.execute("SELECT value FROM blox_profile_config where uuid = '" + recvline.strip() + "'"); #Get LAN Profile

lanprofile = cur.fetchone()['value'] ;

cur.execute("SELECT value FROM blox_config where uuid = 'PBX:" + lanprofile + "'"); #Get RU from LAN Profile
ruconfig = cur.fetchone()['value'];
for v in ruconfig.split(';'): #get WAN profile using RU
	if(re.match("WAN",v)): 
		print "SELECT value FROM blox_profile_config where uuid = '" + v.split('=')[1] + "'" 
		cur.execute("SELECT value FROM blox_profile_config where uuid = '" + v.split('=')[1] + "'")
		wanprofile = cur.fetchone()['value'];
		break ;

if len(watcher_uri.split(':'))<=2:  #First add default 5060 for substution
	watcher_uri_defport = watcher_uri + ':5060' ;
else:
	watcher_uri_defport = watcher_uri ;
	watcher_uri = re.sub(':5060','',watcher_uri); #Remove 5060 for substution

print("SELECT from_uri, to_uri, event, socket, extra_hdr, expiry FROM blox_subscribe where from_uri = '" + watcher_uri + "' or from_uri = '" + watcher_uri_defport + "' ORDER BY last_modified DESC")
cur.execute("SELECT from_uri, to_uri, event, socket, extra_hdr, expiry FROM blox_subscribe where from_uri = '" + watcher_uri + "' or from_uri = '" + watcher_uri_defport + "' ORDER BY last_modified DESC")
result_blox_subscribe = cur.fetchall()


#cur.execute("SELECT id, username, received, callid, contact, received, socket, attr FROM locationpresence group by username, contact order by id")
#cur.execute("SELECT id, username, received, callid, contact, received, socket, attr FROM locationpresence group by username, contact order by last_modified")
cur.execute("SELECT id, username, received, callid, contact, received, socket, attr FROM locationpresence order by last_modified")
result_locationpresence = cur.fetchall();
lprow_hash = dict();

for bsrow in result_blox_subscribe:
	bs_from_uri = bsrow['from_uri'] ;
	bs_to_uri   = bsrow['to_uri'] ;
	if len(bs_to_uri.split(':'))<=2:  #First add default 5060 for substution
		bs_to_uri_defport = bs_to_uri + ':5060' ;
	else:
		bs_to_uri_defport = bs_to_uri ;
		bs_to_uri = re.sub(':5060','',bs_to_uri); #Remove 5060 for substution


	bs_socket   = bsrow['socket'].split(':') ;
	#Match the to_uri of blox_subscribe matching from uri received 
	if(bs_to_uri != from_uri and bs_to_uri_defport != from_uri):
		print "From URI Not Matching " + bs_to_uri + '/' + bs_to_uri_defport + "!=" + from_uri ;
		continue ;	
	recvsocket = parse_uri(recvline);
	#Check the recvsocket is same as blox_subscribe configured socket
	if bs_socket[1] == recvsocket['ip'] and bs_socket[2] == recvsocket['port'] and bs_socket[0] == recvsocket['transport']:
		print "Matching " + bsrow['socket'] + "<>" + recvline ;
	else:
		print "SOCKET Not Matching " + bsrow['socket'] + "<>" + recvline ;
		continue ;
		
	for lprow in result_locationpresence:
		user = lprow['username'] ;
		contact = lprow['contact'] ;
		key = user + contact ;
		if lprow_hash.get(key,None) is not None: #Unique user and contact
			print user + " User already processed " + contact ;
			print "Continue sending the NOTIFY to other SUBSCRIBE"
			#continue ;
		lprow_hash[key] = 1;
		user_pat = r'^sip:' + re.escape(user) + r'@.*' ;
		if not re.match(user_pat,from_uri,re.M|re.I): #Find subscribed user for this user
			print "From URI Not Matching " + from_uri + "~" + user_pat ;
			continue ;
		else:
			print "Matching " + from_uri + "~" + user_pat ;
		localsocket = lprow['socket'].split(':') ;
		#Match the WAN Profile socket with the subscribed user socket
		#print ">>" + localsocket[1] + wanprofile.split(';')[0].split(':')[1] + localsocket[2] + wanprofile.split(';')[0].split(':')[2]
		if(localsocket[1] == wanprofile.split(';')[0].split(':')[1] and \
			localsocket[2] == wanprofile.split(';')[0].split(':')[2]):
			to_uri = "sip:" + user + "@" + localsocket[1] + ":" + localsocket[2]
			send_notify(lprow,watcher_uri,from_uri,to_uri)
		else:
			print "SOCKET Not Matching " + localsocket[1] + "<>" + wanprofile.split(';')[0].split(':')[1] + ":" \
				 + localsocket[2] + "<>" + wanprofile.split(';')[0].split(':')[2]
	#We found the matching from_uri in blox_subscribe and notify has been sent, lets break
	break ;
	
	

cur.close();
db.close() ;
