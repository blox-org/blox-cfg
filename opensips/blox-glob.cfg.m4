# /* Blox is an Opensource Session Border Controller
#  * Copyright (c) 2015-2018 "Blox" [http://www.blox.org]
#  * 
#  * This file is part of Blox.
#  * 
#  * Blox is free software: you can redistribute it and/or modify
#  * it under the terms of the GNU General Public License as published by
#  * the Free Software Foundation, either version 3 of the License, or
#  * (at your option) any later version.
#  * 
#  * This program is distributed in the hope that it will be useful,
#  * but WITHOUT ANY WARRANTY; without even the implied warranty of
#  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  * GNU General Public License for more details.
#  * 
#  * You should have received a copy of the GNU General Public License
#  * along with this program. If not, see <http://www.gnu.org/licenses/> 
#  */


debug=3
fork=yes
log_facility=LOG_LOCAL0
log_stderror=no
children=5
port=5060
dns=no
rev_dns=no

server_header="Server: USERAGENT"
user_agent_header="User-Agent: USERAGENT"

#TLS Configuration
disable_tls=0

log_name="PRODUCT-MAJORVERSION-MINORVERSION-REVNUMBER-RELEASE"

#tos=IPTOS_LOWDELAY
#tos=IPTOS_RELIABILITY
tos=0x10

#tcp_max_connections=1024
#tcp_listen_backlog=10
#tcp_async=1

tcp_keepalive=1
tcp_keepcount=3
tcp_keepidle=30
tcp_keepinterval=10
