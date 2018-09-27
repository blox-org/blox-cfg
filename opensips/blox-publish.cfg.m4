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


route[ROUTE_PUBLISH] {
    if (method == "PUBLISH") {
            if ((uri==myself || from_uri==myself)) {
            #Internal Interface or External
            if($avp(WAN)) {
                xdbg("Got PUBLISH from $Ri WAN\n");
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
                    $var(TLS_BYPASS)="TLS_BYPASS_ENABLED"; if($var(TLS_BYPASS)) { route(ROUTE_TLS_BYPASS); }
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

                    route(BLOX_DOMAIN,$avp(uuid));
                    $var(PBXIP) = $(avp(DEFURI){uri.host}) ;
                    $var(PBXPORT) = $(avp(DEFURI){uri.port}) ;
                    $avp(LANDOMAIN) = $(avp(DEFURI){uri.param,domain});
                    if($avp(LANDOMAIN)==""){$avp(LANDOMAIN)=null;}
                    
                    if($avp(LANDOMAIN)) {
                        $ru = "sip:" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) + ";transport=" + $avp(LANPROTO);
                        $var(puburi) = "sip:" + $tU + "@" + $avp(LANDOMAIN) + ":" + $var(PBXPORT) ;
                    } else {
                        $ru = "sip:" + $var(PBXIP) + ":" + $var(PBXPORT) + ";transport=" + $avp(LANPROTO);
                        $var(puburi) = "sip:" + $tU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) ;
                    }

                    $fs = $avp(LANPROTO) + ":" + $avp(LANIP) + ":" + $avp(LANPORT) ;
                    $du = "sip:" + $var(PBXIP) + ":" +  $var(PBXPORT) + ";transport=" + $avp(LANPROTO)  ;
                    $var(puburi) = "sip:" + $fU + "@" + $var(PBXIP) + ":" + $var(PBXPORT) + ";" + "transport=" + $avp(LANPROTO) ;
                    xlog("Sending to $avp(LANIP) : $avp(LANPORT) : $fs :  $var(puburi)\n");
                    uac_replace_from("$var(puburi)");
                    uac_replace_to("$var(puburi)");
                    #remove_hf("Event");
                    #append_hf("Event: call-completion\r\n");

                    xdbg("SIP Method $rm forwarding to $du\n");
                    if(client_nat_test("3")) {
                        nat_keepalive();
                    }
                    route(2);
                    exit;
                }
            }
        }
        xlog("L_INFO", "PUBLISH Unprocessed, Dropping SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n"); #/* Don't know what to do */
        drop();
        exit;
    };
}
#dnl vim: set ts=4 sw=4 tw=0 et :
