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


modparam("cachedb_local", "cache_table_size", 10)

modparam("drouting", "ruri_avp", "$avp(dr_ruri)")
modparam("drouting", "gw_id_avp", "$avp(dr_gwid)")
modparam("drouting", "rule_id_avp", "$avp(dr_ruleid)")
modparam("drouting", "probing_interval", NAT_KEEPALIVE_INTERVAL)
modparam("drouting", "probing_method", "NAT_KEEPALIVE_METHOD")
modparam("drouting", "probing_from", "NAT_KEEPALIVE_FROMURI")

modparam("nat_traversal", "keepalive_interval", NAT_KEEPALIVE_INTERVAL)
modparam("nat_traversal", "keepalive_method", "NAT_KEEPALIVE_METHOD")
modparam("nat_traversal", "keepalive_from", "NAT_KEEPALIVE_FROMURI")

modparam("dialog", "db_mode", 1)
modparam("dialog","profiles_with_value","outbound; inbound")
#modparam("dialog", "dlg_match_mode", 0)
modparam("dialog","th_callid_passwd","ThisIsABigSecret")
modparam("dialog","th_callid_prefix","BLOX_CALLID_PREFIX")
modparam("dialog", "default_timeout", 3600)
modparam("dialog", "ping_interval", NAT_KEEPALIVE_INTERVAL)

#loadmodule "stun.so"

modparam("acc", "early_media", ACC_FLAG_EARLY_MEDIA)
modparam("acc", "failed_transaction_flag", ACC_FLAG_FAILED_TRANSACTION)
modparam("acc", "report_cancels", ACC_FLAG_REPORT_CANCEL)
modparam("acc", "detect_direction", ACC_FLAG_DETECT_DIRECTION)
modparam("acc", "log_facility", "LOG_LOCAL0")
modparam("acc", "log_level", 3)
modparam("acc", "log_flag", ACC_FLAG_LOG_FLAG)
modparam("acc", "db_flag", ACC_FLAG_DB_FLAG)
modparam("acc", "cdr_flag", ACC_FLAG_CDR_FLAG)
modparam("acc", "log_extra", "src=$dlg_val(from);dst=$dlg_val(request);channel=$dlg_val(channel);dstchannel=$dlg_val(dchannel);direction=$dlg_val(direction)")
modparam("acc", "db_extra",  "src=$dlg_val(from);dst=$dlg_val(request);channel=$dlg_val(channel);dstchannel=$dlg_val(dchannel);direction=$dlg_val(direction)")
#modparam("acc", "multi_leg_info", "leg_src=$avp(src);leg_dst=$avp(dst)")

modparam("usrloc", "nat_bflag", "NAT")
modparam("usrloc", "db_mode",   1)
modparam("auth_db", "password_column", "password")
modparam("auth_db", "calculate_ha1", 1)


################## NAT ######################
modparam("usrloc", "nat_bflag", 6)
modparam("nathelper", "ping_nated_only", 1)
modparam("nathelper", "sipping_bflag", 8)
modparam("nathelper","received_avp","$avp(rcv)")

modparam("registrar","received_avp","$avp(rcv)")
modparam("registrar","received_param","rcv")
modparam("registrar", "attr_avp", "$avp(regattr)")
modparam("registrar", "tcp_persistent_flag", 7)

#modparam("stun","primary_ip","192.168.0.87 / 61.12.12.132")
#modparam("stun","primary_port","5060")

################## NAT ######################

modparam("userblacklist|pua|uac_registrant|load_balancer|dialog|usrloc|auth_db|drouting|acc|avpops", "db_url", "mysql://opensips:opensipsrw@localhost/opensips_1_11")
modparam("uac_registrant", "timer_interval", 10)


modparam("rtpengine", "setid_avp", "$avp(setid)")
import_file  "blox-modparam-rtpengine.cfg"

modparam("mi_fifo", "fifo_name", "/tmp/opensips_fifo")

modparam("tm", "onreply_avp_mode", 1)
#modparam("tm", "ruri_matching", 0)
#modparam("tm", "restart_fr_on_each_reply", 0)
#modparam("tm", "own_timer_proc", 1)

#UAC_AUTH Limitation to increment CSeq during Auth not usefull
#modparam("uac_auth","credential","2020202020:asterisk:2020202020")
#modparam("uac_auth","auth_realm_avp","$avp(auth_domain)")
#modparam("uac_auth","auth_username_avp","$avp(auth_username)")
#modparam("uac_auth","auth_password_avp","$avp(auth_password)")

modparam("uac","restore_mode","auto")

modparam("rest_client", "connection_timeout", 5)
modparam("rest_client", "curl_timeout", 5)
modparam("rest_client", "ssl_verifypeer", 0)
modparam("rest_client", "ssl_verifyhost", 0)

modparam("rr", "append_fromtag", 1)

#list of user agent patterns
modparam("regex", "file", "/usr/local/etc/opensips/regex-groups-all.cfg")
modparam("regex", "pcre_caseless", 1)
modparam("regex", "pcre_multiline", 1)

modparam("cfgutils", "shvset", "yes=s:yes")
modparam("cfgutils", "shvset", "no=s:no")

modparam("dialog","th_dlg_contact_uri_params","th_cthdr")
modparam("dialog","th_dlg_contact_params","th_cthdr_param")

modparam("load_balancer", "probing_interval", LB_KEEPALIVE_INTERVAL)
modparam("load_balancer", "probing_from","LB_KEEPALIVE_FROMURI")
modparam("load_balancer", "probing_reply_codes", "404")
