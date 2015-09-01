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
                xdbg("Got from $Ri LAN\n");
                $avp(uuid) = "PBX:" + $avp(LAN);
                if(cache_fetch("local","$avp(uuid)",$avp(PBXTRUNK))) {
                    xdbg("Loaded from cache $avp(uuid): $avp(PBXTRUNK)\n");
                } else if (avp_db_load("$avp(uuid)","$avp(PBXTRUNK)/blox_config")) {
                    cache_store("local","$avp(uuid)","$avp(PBXTRUNK)");
                    xdbg("Stored in cache $avp(uuid): $avp(PBXTRUNK)\n");
                } else {
                    $avp(PBXTRUNK) = null;
                    xdbg("Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from LAN side, but we don't process it */
                    exit;
                }
                if(cache_fetch("local","$avp(LAN)",$avp(LANProfile))) {
                    xdbg("Loaded from cache $avp(LAN): $avp(LANProfile)\n");
                } else if (avp_db_load("$avp(LAN)","$avp(LANProfile)/blox_profile_config")) {
                    cache_store("local","$avp(LAN)","$avp(LANProfile)");
                    xdbg("Stored in cache $avp(LAN): $avp(LANProfile)\n");
                } else {
                    $avp(LANProfile) = null;
                    xlog("L_INFO", "Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from LAN side, but we don't process it */
                    exit;
                }
                xdbg("PBXTRUNK Profile :$avp(PBXTRUNK):\n");
                $var(PBXTRUNKIP) = $(avp(PBXTRUNK){uri.host});
                $var(PBXTRUNKPORT) = $(avp(PBXTRUNK){uri.port});
                $avp(DOMAIN) = $(avp(LANProfile){uri.param,domain}) ;

                if ($si == $var(PBXTRUNKIP) && $sp == $var(PBXTRUNKPORT)) { /* PBX to SBC */
                    fix_nated_register(); /* will set the (not just contact) received address to put in db */
                    force_rport();
                    if (!proxy_authorize("$avp(DOMAIN)", "subscriber")) {
                          proxy_challenge("$avp(DOMAIN)", "0");
                          exit;
                    };
                    xlog("L_INFO", "SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n");
                    save("locationtrunk");
                    exit;
                };
            } else if($avp(WAN)) {
                xdbg("Got from $Ri WAN\n");
                $avp(uuid) = "PBX:" + $avp(WAN);
                if(cache_fetch("local","$avp(uuid)",$avp(PBX))) {
                    xdbg("Loaded from cache $avp(uuid): $avp(PBX)\n");
                } else if (avp_db_load("$avp(uuid)","$avp(PBX)/blox_config")) {
                    cache_store("local","$avp(uuid)","$avp(PBX)");
                    xdbg("Stored in cache $avp(uuid): $avp(PBX)\n");
                } else {
                    $avp(PBX) = null;
                    xlog("L_INFO", "Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from LAN side, but we don't process it */
                    exit;
                }
                $avp(LAN) = $(avp(PBX){uri.param,LAN}) ;

                if($avp(LAN)) {
                    if(cache_fetch("local","$avp(LAN)",$avp(LANProfile))) {
                        xdbg("Loaded from cache $avp(LAN): $avp(LANProfile)\n");
                    } else if (avp_db_load("$avp(LAN)","$avp(LANProfile)/blox_profile_config")) {
                        cache_store("local","$avp(LAN)","$avp(LANProfile)");
                        xdbg("Stored in cache $avp(LAN): $avp(LANProfile)\n");
                    } else {
                        $avp(LANProfile) = null;
                        xlog("L_INFO", "Drop MESSAGE $ru from $si : $sp\n" );
                        drop(); # /* Default 5060 open to accept packets from LAN side, but we don't process it */
                        exit;
                    }

                    xdbg("Sending to :$avp(LANProfile):\n");
                    $avp(LANIP) = $(avp(LANProfile){uri.host});
                    $avp(LANPORT) = $(avp(LANProfile){uri.port});
                    $avp(LANPROTO) = $(avp(LANProfile){uri.param,transport});
                    fix_nated_register(); /* will set the (not just contact) received address to put in db */
                    force_rport();
                    if(! subst("/Contact: +<sip:(.*)@(.*?)>;(.*)$/Contact: <sip:\1@$avp(LANIP):$avp(LANPORT)>;\3/")) {
                        subst("/Contact: +<sip:(.*)@(.*?)>(.*)$/Contact: <sip:\1@$avp(LANIP):$avp(LANPORT)>/");
                    }

                    $var(PBXIP) = $(avp(PBX){uri.host}) ;
                    $var(PBXPORT) = $(avp(PBX){uri.port}) ;
                    
                    $ru = "sip:" + $var(PBXIP) + ":" + $var(PBXPORT) ;
                    $fs = $avp(LANPROTO) + ":" + $avp(LANIP) + ":" + $avp(LANPORT) ;
                    $du = $avp(PBX) + ";transport=" + $avp(LANPROTO)  ;
                    $var(reguri) = "sip:" + $fU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) + ";" + "transport=" + $avp(LANPROTO) ;
                    xlog("Sending to $avp(LANIP) : $avp(LANPORT) : $fs :  $var(reguri)\n");
                    uac_replace_from("$var(reguri)");
                    uac_replace_to("$var(reguri)");

                    xdbg("SIP Method $rm forwarding to $du\n");
                    if(client_nat_test("3")) {
                        nat_keepalive();
                    }
                    route(WAN2LAN);
                    exit;
                }
            }
        }
        xlog("L_INFO", "REGISTER Unprocessed, Dropping SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n"); #/* Don't know what to do */
        drop();
        exit;
    };
}
