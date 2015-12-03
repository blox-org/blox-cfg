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


route[ROUTE_BYE] {
    if (method == "BYE") {
        if($avp(LAN)) {
            $avp(uuid) = "PBX:" + $avp(LAN) ;
            if(cache_fetch("local","$avp(uuid)",$avp(PBX))) {
                xdbg("BLOX_DBG: Loaded from cache $avp(uuid): $avp(PBX)\n");
            } else if (avp_db_load("$avp(uuid)","$avp(PBX)/blox_config")) {
                cache_store("local","$avp(uuid)","$avp(PBX)");
                xdbg("BLOX_DBG: Stored in cache $avp(uuid): $avp(PBX)\n");
            } else {
                xlog("L_WARN", "SIP Profile for $si:$sp access denied\n");
                sl_send_reply("603", "Declined");
                exit;
            }

            if($avp(PBX)) {
                $avp(WAN) = $(avp(PBX){uri.param,WAN});

                if(cache_fetch("local","$avp(WAN)",$avp(WANProfile))) {
                    xdbg("BLOX_DBG: Loaded from cache $avp(WAN): $avp(WANProfile)\n");
                } else if (avp_db_load("$avp(WAN)","$avp(WANProfile)/blox_profile_config")) {
                    cache_store("local","$avp(WAN)","$avp(WANProfile)");
                    xdbg("BLOX_DBG: Stored in cache $avp(WAN): $avp(WANProfile)\n");
                } else {
                    $avp(WANProfile) = null;
                    xlog("L_INFO", "Drop MESSAGE $ru from $si : $sp\n" );
                    drop(); # /* Default 5060 open to accept packets from WAN side, but we don't process it */
                    exit;
                }

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
                xdbg("BLOX_DBG: Looking for $var(aor) in locationpbx\n");

                # /* Last Check for Roaming Extension */
                if (!lookup("locationpbx","m", "$var(aor)")) { ; #/* Find RE Registered to US */
                    switch ($retcode) {
                        case -1:
                        case -3:
                            t_newtran();
                            t_reply("404", "Not Found");
                            exit;
                        case -2:
                            append_hf("Allow: INVITE, ACK, REFER, NOTIFY, CANCEL, BYE, REGISTER" );
                            sl_send_reply("405", "Method Not Allowed");
                            exit;
                    }
                };

                if($var(ENUMSE) != null && $var(ENUMSX) != null) {
                    route(ENUM,$var(ENUMTYPE),$var(ENUMSX),$var(ENUMSE));
                }

                xlog("L_INFO","Found PBX Requesting $ru -> $var(to)/$du -> $var(from)" );
            }
        }
    }
}
