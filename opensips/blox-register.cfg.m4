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


route[ROUTE_REGISTER] {
    if (method == "REGISTER") {
            if ((uri==myself || from_uri==myself)) {
            #Internal Interface or External
            if($avp(LAN)) {
                xlog("L_INFO","BLOX_DBG: Got from $Ri LAN, No Trunk REGISTER\n");
            } else if($avp(WAN)) {
                xdbg("BLOX_DBG: Got from $Ri WAN\n");
                $avp(uuid) = "PBX:" + $avp(WAN);
                if(cache_fetch("local","$avp(uuid)",$avp(PBX))) {
                    xdbg("BLOX_DBG: Loaded from cache $avp(uuid): $avp(PBX)\n");
                } else if (avp_db_load("$avp(uuid)","$avp(PBX)/blox_config")) {
                    cache_store("local","$avp(uuid)","$avp(PBX)");
                    xdbg("BLOX_DBG: Stored in cache $avp(uuid): $avp(PBX)\n");
                } else {
                    $avp(PBX) = null;
                    xlog("L_INFO", "BLOX_DBG::: blox-register.cfg: Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from LAN side, but we don't process it */
                    exit;
                }
                $avp(LAN) = $(avp(PBX){uri.param,LAN}) ;

                if($avp(LAN)) {
                    route(READ_LAN_PROFILE);
                    xdbg("BLOX_DBG: Sending via LAN Profile :$avp(LANProfile):\n");
                    $avp(LANIP) = $(avp(LANProfile){uri.host});
                    $avp(LANPORT) = $(avp(LANProfile){uri.port});
                    $avp(LANPROTO) = $(avp(LANProfile){uri.param,transport});
                    $avp(rcv) = "sip:" + $(var(cturi){uri.host}) + ":" + $(var(cturi){uri.port}) + ";transport=" + $proto ;
                    if($var(nat96)) { # /* If Contact not same as source IP Address */
                        if(!is_ip_rfc1918("$si")) { # /* Source is not Priviate IP */
                            fix_nated_register(); /* will set the (not just contact) received address to put in db */
                        }
                    }
                    xdbg("BLOX_DBG::: blox-register.cfg: REGISTER processed, $si $sp to $ru ($avp(rcv))/$var(cturi)\n"); #/* Don't know what to do */
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
                        $ru = "sip:" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) + ";transport=" + $avp(LANPROTO);
                        $var(reguri) = "sip:" + $tU + "@" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) ;
                    } else {
                        $ru = "sip:" + $var(PBXIP) + ":" + $var(PBXPORT) + ";transport=" + $avp(LANPROTO);
                        $var(reguri) = "sip:" + $tU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) ;
                    }

                    $fs = $avp(LANPROTO) + ":" + $avp(LANIP) + ":" + $avp(LANPORT) ;
                    $du = "sip:" + $var(PBXIP) + ":" +  $var(PBXPORT) + ";transport=" + $avp(LANPROTO)  ;
                    xlog("BLOX_DBG::: blox-register.cfg: Sending via :$fs: to $var(reguri)\n");
                    uac_replace_from("$var(reguri)");
                    uac_replace_to("$var(reguri)");
                    remove_hf("Route"); #Not accepted for REGISTER
                    add_path();

                    xdbg("BLOX_DBG: SIP Method $rm forwarding to $du\n");
                    if(client_nat_test("3")) {
                        nat_keepalive();
                    }

                    t_on_reply("WAN2LAN_REGISTER");

                    if($var(SHMPACT)) {
                        route(SIP_HEADER_MANIPULATE,$var(SHMPACT));
                    }
                    if (!t_relay()) {
                        xlog("L_ERR", "BLOX_DBG::: blox-register.cfg: REGISTER Relay error $mb\n");
                        sl_reply_error();
                    };

                    exit;
                }
            }
        }
        xlog("L_INFO", "BLOX_DBG::: blox-register.cfg: REGISTER Unprocessed, Dropping SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n"); #/* Don't know what to do */
        drop();
        exit;
    };
}

onreply_route[WAN2LAN_REGISTER] {
    remove_hf("User-Agent");
    insert_hf("User-Agent: USERAGENT\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT\r\n","CSeq") ;
    }

    xdbg("BLOX_DBG: Got Response $rs/ $fu/$ru/$si/$ci/$avp(rcv)\n");

    if(is_method("REGISTER")) {
        if(status =~ "200") {
            xdbg("BLOX_DBG: Got REGISTER REPLY $fu/$ru/$si/$ci/$avp(rcv)" );
            $avp(regattr) = $pr + ":" + $si + ":" + $sp ;
            $var(aor) = "sip:" + $tU + "@" + $avp(WANIP) + ":" + $avp(WANPORT) ;
            $var(expires) = $ct.fields(expires) ;
            if($var(expires)==null||$var(expires)=="") {
              $var(expires) = $hdr(Expires) ;
            }
            if($var(expires)==null||$var(expires)=="") {
              $var(sflg) = "rp1fc1" ;
            } else {
              $var(sflg) = "rp1fc1E" + $var(expires) ;
            }
  
            if(!save("locationpbx","$var(sflg)", "$var(aor)")) {
                xlog("L_ERROR", "BLOX_DBG::: blox-register.cfg: Error saving the location\n");
            };

            if($avp(WANADVIP)) { # Roaming user: replace it with advIP:Port
                if(!subst("/Contact: +<sip:(.*)@(.*?)>;(.*)$/Contact: <sip:\1@$avp(WANADVIP):$avp(WANADVPORT)>;\3/")) {
                    subst("/Contact: +<sip:(.*)@(.*?)>(.*)$/Contact: <sip:\1@$avp(WANADVIP):$avp(WANADVPORT)>/");
                }
            } else {
                if(!subst("/Contact: +<sip:(.*)@(.*?)>;(.*)$/Contact: <sip:\1@$avp(WANIP):$avp(WANPORT)>;\3/")) {
                    subst("/Contact: +<sip:(.*)@(.*?)>(.*)$/Contact: <sip:\1@$avp(WANIP):$avp(WANPORT)>/");
                }
            }

            xdbg("BLOX_DBG: Saved Location $fu/$ru/$si/$ci/$avp(rcv)" );
        };
        exit;
    };
}
