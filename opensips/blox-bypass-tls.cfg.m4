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


route[ROUTE_TLS_BYPASS] {
        if ((uri==myself || from_uri==myself)) {
            #Internal Interface or External
            if($avp(LAN)) {
                xlog("L_INFO","BLOX_DBG: blox-bypass-tls.cfg Got $rm from $Ri LAN\n");
                $avp(uuid) = "PBX:" + $avp(LAN) ;
                if(cache_fetch("local","$avp(uuid)",$avp(PBX))) {
                    xdbg("BLOX_DBG: blox-bypass-tls.cfg: Loaded from cache $avp(uuid): $avp(PBX)\n");
                } else if (avp_db_load("$avp(uuid)","$avp(PBX)/blox_config")) {
                    cache_store("local","$avp(uuid)","$avp(PBX)");
                    xdbg("BLOX_DBG: blox-bypass-tls.cfg: Stored in cache $avp(uuid): $avp(PBX)\n");
                } else {
                    xlog("L_WARN", "BLOX_DBG::: blox-bypass-tls.cfg: SIP Profile for $si:$sp access denied\n");
                    sl_send_reply("603", "Declined");
                    exit;
                }

                if($avp(PBX)) {
                    xdbg("BLOX_DBG: blox-bypass-tls.cfg: Got route $Ri RE\n");
                    $avp(WAN) = $(avp(PBX){uri.param,WAN});
                    if($avp(WAN)==""){$avp(WAN)=null;}
                    route(READ_WAN_PROFILE);
                    if($avp(WANProfile)) {
                        $avp(WANIP) = $(avp(WANProfile){uri.host});
                        $avp(WANPORT) = $(avp(WANProfile){uri.port});
                        $avp(WANPROTO) = $(avp(WANProfile){uri.param,transport});
                        $avp(WANADVIP) = $(avp(WANProfile){uri.param,advip});
                        $avp(WANADVPORT) = $(avp(WANProfile){uri.param,advport});
                        $fs = $avp(WANPROTO) + ":" + $avp(WANIP) + ":" + $avp(WANPORT);
                    }
                    #search for aor mapped to pbx wan profile
                    $var(aor) = "sip:" + $tU + "@" + $avp(WANIP) + ":" + $avp(WANPORT) ;

                    if($avp(WANPROTO) == "tls") { #/* Proceed only TLS */
                        xlog("L_INFO","BLOX_DBG: blox-bypass-tls.cfg: Looking for $var(aor) in locationpbx\n");
                    } else {
                        return(1);
                    }

                    # /* Last Check for Roaming Extension */
                    if (!lookup("locationpbx","", "$var(aor)")) { ; #/* Find RE Registered to US */
                        switch ($retcode) {
                            case -1:
                            case -3:
                                t_newtran();
                                xlog("L_INFO","BLOX_DBG: blox-bypass-tls.cfg: Failed $var(aor)\n"); 
                                t_reply("404", "Not Found");
                                exit;
                            case -2:
                                append_hf(BLOX_ALLOW_HDR);
                                sl_send_reply("405", "Method Not Allowed");
                                exit;
                        }
                    };


                    if($avp(WANADVIP)) {
                        $var(to) = "sip:" + $tU + "@" + $avp(WANADVIP) + ":" + $avp(WANADVPORT) + ";transport=" + $avp(WANPROTO);
                        $var(from) = "sip:" + $fU + "@" + $avp(WANADVIP) + ":" + $avp(WANADVPORT) + ";transport=" + $avp(WANPROTO);
                    } else {
                        $var(to) = "sip:" + $tU + "@" + $avp(WANIP) + ":" + $avp(WANPORT) + ";transport=" + $avp(WANPROTO);
                        $var(from) = "sip:" + $fU + "@" + $avp(WANIP) + ":" + $avp(WANPORT) + ";transport=" + $avp(WANPROTO);
                    }
                    if(!has_totag()) {
                        uac_replace_to("$var(to)");
                        uac_replace_from("$var(from)");
                    }
                    xlog("L_INFO", "BLOX_DBG::: blox-bypass-tls.cfg: Found PBX Requesting $ru -> $var(to)/$du -> $var(from)" );

                    t_on_reply("LAN2WAN_TLS_BYPASS");

                    if($var(SHMPACT)) {
                        route(SIP_HEADER_MANIPULATE,$var(SHMPACT));
                    }
                    if (!t_relay()) {
                        xlog("L_ERR", "BLOX_DBG::: blox-bypass-tls.cfg: $rm Relay error $mb\n");
                        sl_reply_error();
                    };
                    exit;
                }
            } else if($avp(WAN)) {
                if($proto == "tls") {
                    xdbg("BLOX_DBG: Relay $rm only from $proto\n");
                } else {
                    return(1);
                }
                xdbg("BLOX_DBG: Got from $Ri WAN\n");
                $avp(uuid) = "PBX:" + $avp(WAN);
                if(cache_fetch("local","$avp(uuid)",$avp(PBX))) {
                    xdbg("BLOX_DBG: Loaded from cache $avp(uuid): $avp(PBX)\n");
                } else if (avp_db_load("$avp(uuid)","$avp(PBX)/blox_config")) {
                    cache_store("local","$avp(uuid)","$avp(PBX)");
                    xdbg("BLOX_DBG: Stored in cache $avp(uuid): $avp(PBX)\n");
                } else {
                    $avp(PBX) = null;
                    xlog("L_INFO", "BLOX_DBG::: blox-bypass-tls.cfg: Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from LAN side, but we don't process it */
                    exit;
                }
                if($avp(PBX)) {
                    $avp(LAN) = $(avp(PBX){uri.param,LAN}) ;
                    if($avp(LAN)==""){$avp(LAN)=null;}
                    route(READ_LAN_PROFILE);

                    xdbg("BLOX_DBG: Sending via LAN Profile :$avp(LANProfile):\n");
                    $avp(LANIP) = $(avp(LANProfile){uri.host});
                    $avp(LANPORT) = $(avp(LANProfile){uri.port});
                    $avp(LANPROTO) = $(avp(LANProfile){uri.param,transport});
                    xdbg("BLOX_DBG::: blox-bypass-tls.cfg: $rm processed, $si $sp to $ru ($avp(rcv))/$var(cturi)\n"); #/* Don't know what to do */
                    if($var(fixnat)) {
                        xdbg("BLOX_DBG::: blox-bypass-tls.cfg: NAT Fixed already req: $ru contact: $ct rcv: $avp(rcv)"); 
                    } else {
                        $avp(rcv) = "sip:" + $(var(cturi){uri.host}) + ":" + $(var(cturi){uri.port}) + ";transport=" + $proto ;
                    }
                    force_rport();
                    if(! subst("/Contact: +<sip:(.*)@(.*?)>;(.*)$/Contact: <sip:\1@$avp(LANIP):$avp(LANPORT)>;\3/")) {
                        subst("/Contact: +<sip:(.*)@(.*?)>(.*)$/Contact: <sip:\1@$avp(LANIP):$avp(LANPORT)>/");
                    }

                    route(BLOX_DOMAIN,$avp(uuid));
                    $var(PBXIP) = $(avp(DEFURI){uri.host}) ;
                    $var(PBXPORT) = $(avp(DEFURI){uri.port}) ;
                    $avp(LANDOMAIN) = $(avp(DEFURI){uri.param,domain});
                    if($avp(LANDOMAIN)==""){$avp(LANDOMAIN)=null;}
                    
                    if($avp(LANDOMAIN)) {
                        $ru = "sip:" + $rU + "@" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) + ";transport=" + $avp(LANPROTO);
                        $var(furi) = "sip:" + $fU + "@" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) ;
                        $var(turi) = "sip:" + $tU + "@" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) ;
                    } else {
                        $ru = "sip:" + $rU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) + ";transport=" + $avp(LANPROTO);
                        $var(furi) = "sip:" + $fU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) ;
                        $var(turi) = "sip:" + $tU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) ;
                    }

                    $fs = $avp(LANPROTO) + ":" + $avp(LANIP) + ":" + $avp(LANPORT) ;
                    $du = "sip:" + $var(PBXIP) + ":" +  $var(PBXPORT) + ";transport=" + $avp(LANPROTO)  ;
                    xlog("BLOX_DBG::: blox-bypass-tls.cfg: Sending via :$fs: to $var(reguri)\n");
                    if(!has_totag()) {
                        uac_replace_from("$var(furi)");
                        uac_replace_to("$var(turi)");
                    }

                    xdbg("BLOX_DBG: SIP Method $rm forwarding to $du\n");
                    t_on_reply("WAN2LAN_TLS_BYPASS");

                    if($var(SHMPACT)) {
                        route(SIP_HEADER_MANIPULATE,$var(SHMPACT));
                    }
                    if (!t_relay()) {
                        xlog("L_ERR", "BLOX_DBG::: blox-bypass-tls.cfg: $rm Relay error $mb\n");
                        sl_reply_error();
                    };

                    exit;
                }
            }
        }
        xlog("L_INFO", "BLOX_DBG::: blox-bypass-tls.cfg: $rm Unprocessed, Dropping SIP Method $rm received req:$ru fu:$fu $si:$sp to $ru ($avp(rcv))/ua:$ua\n"); #/* Don't know what to do */
}

onreply_route[WAN2LAN_TLS_BYPASS] {
    remove_hf("User-Agent");
    insert_hf("User-Agent: USERAGENT\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT\r\n","CSeq") ;
    }

    xdbg("BLOX_DBG: Got Response $rs/ $fu/$ru/$si/$ci/$avp(rcv)\n");

    if(status =~ "200") {
        xdbg("BLOX_DBG: Got $rm REPLY $fu/$ru/$si/$ci/$avp(rcv)" );
        $avp(regattr) = $pr + ":" + $si + ":" + $sp ;
        $var(aor) = "sip:" + $tU + "@" + $avp(WANIP) + ":" + $avp(WANPORT) ;

        if($avp(WANADVIP)) { # Roaming user: replace it with advIP:Port
            if(!subst("/Contact: +<sip:(.*)@(.*?)>;(.*)$/Contact: <sip:\1@$avp(WANADVIP):$avp(WANADVPORT)>;\3/")) {
                subst("/Contact: +<sip:(.*)@(.*?)>(.*)$/Contact: <sip:\1@$avp(WANADVIP):$avp(WANADVPORT)>/");
            }
        } else {
            if(!subst("/Contact: +<sip:(.*)@(.*?)>;(.*)$/Contact: <sip:\1@$avp(WANIP):$avp(WANPORT)>;\3/")) {
                subst("/Contact: +<sip:(.*)@(.*?)>(.*)$/Contact: <sip:\1@$avp(WANIP):$avp(WANPORT)>/");
            }
        }
    };
    exit;
}

onreply_route[LAN2WAN_TLS_BYPASS] {
    xlog("L_INFO","BLOX_DBG::: blox-bypass-tls.cfg: Got Response for $rm:$cs code:$rs from:$fu ru:$ru src:$si:$sp callid:$ci rcv:$Ri:$Rp\n");
}
#dnl vim: set ts=4 sw=4 tw=0 et :
