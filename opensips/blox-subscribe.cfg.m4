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

route[ROUTE_SUBSCRIBE] {
    if (method == "SUBSCRIBE") {
        if ((uri==myself || from_uri==myself)) {
            if($avp(WAN)) {
                if(cache_fetch("local","$avp(WAN)",$avp(WANProfile))) {
                    xdbg("Loaded from cache $avp(WAN): $avp(WANProfile)\n");
                } else if (avp_db_load("$avp(WAN)","$avp(WANProfile)/blox_profile_config")) {
                    cache_store("local","$avp(WAN)","$avp(WANProfile)");
                    xdbg("Stored in cache $avp(WAN): $avp(WANProfile)\n");
                } else {
                    $avp(WANProfile) = null;
                    xlog("L_WARN", "No WAN profile Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from WAN side, but we don't process it */
                    exit;
                }

                $avp(WANDOMAIN) = "" ;
                if($avp(WANProfile)) {
                    $avp(WANDOMAIN) = $(avp(WANProfile){uri.param,domain});
                }

                fix_nated_register();
                force_rport();
                if (!proxy_authorize("$avp(WANDOMAIN)", "blox_presence_subscriber")) {
                      proxy_challenge("$avp(DOMAIN)", "0");
                      xlog("L_INFO", "Challenge>>>$ft >>>$avp(regattr)>>> SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n");
                      exit;
                };
                $avp(regattr) = $ft ;
                if($hdr(Proxy-Authorization)) {
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
                    $var(PBXIP) = $(avp(PBX){uri.host}) ;
                    $var(PBXPORT) = $(avp(PBX){uri.port}) ;
                    
                    $avp(attr) = "subscribe";
                    $avp(val) = 'sip:' + $tU + '@' + $var(PBXIP) + ':' + $var(PBXPORT);
                    raise_event("E_SCRIPT_EVENT", $avp(attr), $avp(val));    
                    xlog("L_INFO", "Saving $avp(attr) : $avp(val) SUCESS>>>$hdr(Proxy-Authorization) >> $ft >>>$avp(regattr)>>> SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n");
                    save("locationpresence");
                }
                exit;
            }
        }

        xlog("L_INFO", "SUBSCRIBE Unprocessed, Dropping SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n"); #/* Don't know what to do */
        drop();
        exit;
    };
}
