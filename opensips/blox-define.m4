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

divert(-1)
define(`USERAGENT',`Blox')
define(`gMTSSRV',`http://127.0.0.1:8000')
define(`gMediaPortOffset',`4')
define(`gMAX_OUTBOUND',`100')
define(`gMAX_INBOUND',`100')
define(`LAN2WAN',`1')
define(`WAN2LAN',`2')
define(`LCR_MATCH',`3')
define(`ROUTE_REGISTER',`301')
define(`ROUTE_INVITE',`302')
define(`ROUTE_CANCEL',`303')
define(`DELETE_ALLOMTS_RESOURCE',`111')
define(`CONNECT_ALLOMTS_RESOURCE',`120')
define(`DISCONNECT_ALLOMTS_RESOURCE',`121')
define(`OUTBOUND_CALL_ACCESS_CONTROL',`20')
define(`INBOUND_CALL_ACCESS_CONTROL',`21')
define(`MAX_SIP_MSG_LENGTH',`2048')
define(`MAX_SIP_MAXFWD',`10')
define(`DLG_FLAG_LAN2WAN',`1')
define(`DLG_FLAG_WAN2LAN',`2')
define(`DLG_FLAG_TRANSCODING',`3')
define(`ACC_FLAG_EARLY_MEDIA',`1')
define(`ACC_FLAG_REPORT_CANCEL',`1')
define(`ACC_FLAG_DETECT_DIRECTION',`1')
define(`ACC_FLAG_CDR_FLAG',`2')
define(`ACC_FLAG_LOG_FLAG',`4')
define(`ACC_FLAG_DB_FLAG',`3')
define(`ACC_FLAG_FAILED_TRANSACTION',`9')
define(`SRTP_DISABLE',`"0"')
define(`SRTP_OPTIONAL',`"1"')
define(`SRTP_COMPULSORY',`"2"')
divert(0)dnl
