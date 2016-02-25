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


def convert_with_defport(uri):
	minsplit = 2 ;
	if(re.match(r'^[a-zA-Z]+:',uri)):
		minsplit = 3 ;
	if len(uri.split(':'))<minsplit:
		return (uri + ':5060') ;
	return uri ;

def convert_without_defport(uri):
	minsplit = 2 ;
	if(re.match(r'^[a-zA-Z]+:',uri)):
		minsplit = 3 ;
	if len(uri.split(':'))>=minsplit: 
		return re.sub(':5060','',uri); #Remove 5060 for substution
	return uri ;

#row,ruri(request uri),furi(from uri), touri(to uri), EVENT_TYPE(presence,message-summary)
def send_notify(lprow,ruri,furi,touri,EVENT_TYPE):
	content_length=0
	nfd = open(notify_file,"r",1);
	recvline = nfd.readline(); #Ignore this customized line
	localsocket = lprow['socket'].split(':');
	localsocket_uri = localsocket[1] + ':' + localsocket[2] + ';transport=' + localsocket[0] ;
	contact = lprow['contact'].split('@') ;
	replace_request_uri = contact[0] + '@' + localsocket_uri ;
	replace_to_uri   = contact[0] + '@' + localsocket_uri ;
	replace_from_uri = 'sip:' + lprow['username'] + '@' + localsocket_uri ;

	notify_file_out = "/var/tmp/" + replace_from_uri + ".out"
	nfd_w = open(notify_file_out,"w",1);

	ruri_defport = convert_with_defport(ruri);
	ruri         = convert_without_defport(ruri);
	touri_defport = convert_with_defport(touri);
	touri         = convert_without_defport(touri);
	furi_defport  = convert_with_defport(furi);
	furi          = convert_without_defport(furi);

	print 'from_uri:' + furi_defport  + '===' +  furi  + "==" + replace_from_uri;
	print 'to_uri:'   + touri_defport + '===' +  touri + "==" + replace_to_uri;
	print 'wt_uri:'   + ruri_defport + '===' +  ruri + "==" + replace_request_uri;

	for line in nfd:
		#print line.strip() ;
		if re.match(r'Via:',line,re.M|re.I):
			line = re.sub(r'Via: SIP/2.0/UDP (.*);branch=(.*)',r'Via: SIP/2.0/UDP 127.0.0.1:7777;branch=\2',line)
		elif re.match(r'To:',line,re.M|re.I):
			if EVENT_TYPE == "presence":
				replace_from_pat = r'To:\1;tag='+ re.escape(lprow['attr']) + r'\3\r\n'
				line = re.sub(r'To:(.*);tag=(.*)(;*.*)\r\n',replace_from_pat,line)
		elif re.match(r'Call-ID:',line,re.M|re.I):
			line = re.sub(r'Call-ID:(.*)\r\n','Call-ID: ' + lprow['callid'] + '\r\n',line)
		elif re.match('\r\n',line,re.M|re.I):
			break ;

		(line,cnt) = re.subn(ruri_defport,replace_request_uri,line)
		if(cnt==0):
			line = re.sub(ruri,replace_request_uri,line)

		(line,cnt) = re.subn(furi_defport,replace_from_uri,line)
		if(cnt==0):
			line = re.sub(furi,replace_from_uri,line)

		(line,cnt) = re.subn(touri_defport,replace_to_uri,line)
		if(cnt==0):
			line = re.sub(touri,replace_to_uri,line)

		if re.match(r'Content-Length:',line,re.M|re.I):
			line = None ;

		if line is not None:
			nfd_w.write(line) 
			#print "<<=X=>>" + line.strip();


	content = "" ;
	for line in nfd:
		content_length += len(line) ;
		content += line ;

	(content,cnt) = re.subn(ruri_defport,replace_request_uri,content)
	if(cnt==0):
		content = re.sub(ruri,replace_request_uri,content)

	(content,cnt) = re.subn(furi_defport,replace_from_uri,content)
	if(cnt==0):
		content = re.sub(furi,replace_from_uri,content)

	(content,cnt) = re.subn(touri_defport,replace_to_uri,content)
	if(cnt==0):
		content = re.sub(touri,replace_to_uri,content)

	if EVENT_TYPE == "message-summary":
		pbxsocket = parse_uri(lprow['attr']);
		pbxipport = pbxsocket['ip'] + ':' + pbxsocket['port'];
		pbxipport_defport = convert_with_defport(pbxipport);
		pbxipport         = convert_without_defport(pbxipport);
		(content,cnt) = re.subn(pbxipport_defport,localsocket_uri,content)
		if(cnt==0):
			content = re.sub(pbxipport,localsocket_uri,content)

	nfd_w.write('Remote-Contact-Header: ' + lprow['received'] + '\r\n') ;
	nfd_w.write('Send-Socket: ' + lprow['socket'] + '\r\n') ;
	nfd_w.write('Content-Length: ' + `content_length` + "\r\n\r\n") 
	nfd_w.write(content)

	nfd.close()
	nfd_w.close()
	#print notify_file_out
	send_to_server(notify_file_out)
	#print_filecontent(notify_file_out)


def SQLConnect(host,user,passwd,dbname):
	db = MySQLdb.connect(host, # your host, usually localhost
                     user, # your username
                      passwd, # your password
                      dbname) # name of the data base
	return db ;

def SQLCursor(db):
	return db.cursor(cursorclass=MySQLdb.cursors.DictCursor)
	
def SQLExecute(cur,sql):
	print sql ;
	return cur.execute(sql);	


#MAIN()
nfd = open(notify_file,"r",1);
lanprofile = nfd.readline();
reqline = nfd.readline().split()
if reqline[0] == "NOTIFY":
	print "LANProfile:" + lanprofile 
	print reqline[0]
else:
	print "Error: Not NOTIFY"
	print "LANProfile:" + lanprofile 
	print reqline[0]
	nfd.close();
	sys.exit(-1) ;

request_uri = reqline[1] ;

if len(request_uri.split(':'))<=2:  #First add default 5060 for substution
	request_uri_defport = request_uri + ':5060' ;
else:
	request_uri_defport = request_uri ;
	request_uri = re.sub(':5060','',request_uri); #Remove 5060 for substution

for line in nfd:
	print line.strip();
	if re.match(r'From:',line,re.M|re.I):
		from_uri = re.sub(r'From:\s*(.*)',r'\1',line.split(';')[0])
	if re.match(r'Event:',line,re.M|re.I):
		EventType = re.sub(r'Event:\s*(.*)',r'\1',line.split(';')[0])
nfd.close() ;

from_uri = from_uri.strip();
EventType = EventType.strip();


db = SQLConnect("localhost","opensips","opensipsrw","opensips_1_11");
cur = SQLCursor(db);

if EventType == "presence":
	SQLExecute(cur,"SELECT from_uri, to_uri, event, socket, extra_hdr, expiry FROM blox_subscribe where from_uri = '" + request_uri + "' or from_uri = '" + request_uri_defport + "' ORDER BY last_modified DESC")
	result_blox_subscribe = cur.fetchall()
	SQLExecute(cur,"SELECT id, username, received, callid, contact, received, socket, attr FROM locationpresence order by last_modified")
	result_location = cur.fetchall();
	lprow_hash = dict();
elif EventType == "message-summary":
	SQLExecute(cur,"SELECT id, username, received, callid, contact, received, socket, attr FROM locationpbx      order by last_modified")
	result_location = cur.fetchall();
	lprow_hash = dict();
else:
	print "Unsupported Event Type :" + EventType + ":";


SQLExecute(cur,"SELECT value FROM blox_profile_config where uuid = '" + lanprofile.strip() + "'"); #Get LAN Profile

lanid = cur.fetchone()['value'] ;

SQLExecute(cur,"SELECT value FROM blox_config where uuid = 'PBX:" + lanid + "'"); #Get RU from LAN Profile
ruconfig = cur.fetchone()['value'];
for v in ruconfig.split(';'): #get WAN profile using RU
	if(re.match("WAN",v)): 
		print "SELECT value FROM blox_profile_config where uuid = '" + v.split('=')[1] + "'" 
		SQLExecute(cur,"SELECT value FROM blox_profile_config where uuid = '" + v.split('=')[1] + "'")
		wanprofile = cur.fetchone()['value'];
		break ;


if EventType == "presence":
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
		lansocket = parse_uri(lanprofile);
		#Check the lansocket is same as blox_subscribe configured socket
		if bs_socket[1] == lansocket['ip'] and bs_socket[2] == lansocket['port'] and bs_socket[0] == lansocket['transport']:
			print "Matching " + bsrow['socket'] + "<>" + lanprofile;
		else:
			print "SOCKET Not Matching " + bsrow['socket'] + "<>" + lanprofile;
			continue ;
			
		for lprow in result_location:
			#for f in lprow:
			#	print (f,':',lprow[f]);
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
				#send_notify(lprow,request_uri,from_uri,to_uri,EventType)
				send_notify(lprow,request_uri,from_uri,request_uri,EventType) #to_uri same as request uri which needs to be replaced
			else:
				print "SOCKET Not Matching " + localsocket[1] + "<>" + wanprofile.split(';')[0].split(':')[1] + ":" \
					 + localsocket[2] + "<>" + wanprofile.split(';')[0].split(':')[2]
		#We found the matching from_uri in blox_subscribe and notify has been sent, lets break
		break ;
elif EventType == "message-summary":
	for lprow in result_location:
		user = lprow['username'] ;
		contact = lprow['contact'] ;
		key = user + contact ;
		if lprow_hash.get(key,None) is not None: #Unique user and contact
			print user + " User already processed " + contact ;
			print "Continue sending the NOTIFY to other SUBSCRIBE"
			#continue ;
		lprow_hash[key] = 1;
		#user_pat = r'^sip:' + re.escape(user) + r'@.*' ;
		#if not re.match(user_pat,from_uri,re.M|re.I): #Find subscribed user for this user
		#	print "From URI Not Matching " + from_uri + "~" + user_pat ;
		#	continue ;
		#else:
		#	print "Matching " + from_uri + "~" + user_pat ;
		localsocket = lprow['socket'].split(':') ;
		#Match the WAN Profile socket with the subscribed user socket
		#print ">>" + localsocket[1] + wanprofile.split(';')[0].split(':')[1] + localsocket[2] + wanprofile.split(';')[0].split(':')[2]
		if(localsocket[1] == wanprofile.split(';')[0].split(':')[1] and \
			localsocket[2] == wanprofile.split(';')[0].split(':')[2]):
			to_uri = "sip:" + user + "@" + localsocket[1] + ":" + localsocket[2]
			#send_notify(lprow,request_uri,from_uri,to_uri,EventType)
			send_notify(lprow,request_uri,from_uri,request_uri,EventType) #to_uri same as request uri which needs to be replaced
		else:
			print "SOCKET Not Matching " + localsocket[1] + "<>" + wanprofile.split(';')[0].split(':')[1] + ":" \
				 + localsocket[2] + "<>" + wanprofile.split(';')[0].split(':')[2]
else:
	print "Unsupported Event Type :" + EventType + ":";

cur.close();
db.close() ;
