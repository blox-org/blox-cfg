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


route[LAN2WAN] {
    remove_hf("User-Agent");
    insert_hf("User-Agent: USERAGENT\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT\r\n","CSeq") ;
    }

    if($dlg_val(MediaProfileID)) {
        $avp(MediaProfileID) = $dlg_val(MediaProfileID);
    }

    if (has_body("application/sdp")) {
        if(cache_fetch("local","$avp(MediaProfileID)",$avp(MediaProfile))) {
            xdbg("Loaded from cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else if (avp_db_load("$avp(MediaProfileID)","$avp(MediaProfile)/blox_profile_config")) {
            cache_store("local","$avp(MediaProfileID)","$avp(MediaProfile)");
            xdbg("Stored in cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else {
            xlog("L_INFO", "No profile configured for $avp(MediaProfileID): $avp(MediaProfile)\n");
            sl_send_reply("500","Internal Server error");
            exit;
        }

        $avp(MediaLANIP) = $(avp(MediaProfile){param.value,LAN});
        if($avp(WANADVIP)) {
            $avp(MediaWANIP) = $avp(WANADVIP) ;
        } else {
            $avp(MediaWANIP) = $(avp(MediaProfile){param.value,WAN});
        }
        $avp(MediaTranscoding) = $(avp(MediaProfile){param.value,TRANSCODING});
        #$avp(MediaTranscoding) = 0;

        if(is_dlg_flag_set("DLG_FLAG_TRANSCODING")) {
            rtpproxy_unforce("$avp(MediaProfileID)");
        }

        if(is_dlg_flag_set("DLG_FLAG_LAN2WAN")) { #Org Call Intiated from LAN2WAN
                if($DLG_dir == "downstream") { /* Set aprop. LAN WAN Media IP */
                    $avp(DstMediaIP) = $avp(MediaWANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaLANIP) ;
                } else {
                    $avp(DstMediaIP) = $avp(MediaLANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaWANIP) ;
                }
        } else { #Should be Re-Invite from LAN2WAN
                if($DLG_dir == "downstream") { /* Set aprop. LAN WAN Media IP */
                    $avp(DstMediaIP) = $avp(MediaLANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaWANIP) ;
                } else {
                    $avp(DstMediaIP) = $avp(MediaWANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaLANIP) ;
                }
        }

        rtpproxy_offer("o","$avp(DstMediaIP)","$avp(MediaProfileID)","$var(proxy)","$var(newaddr)");
        xdbg("Route: rtpproxy_offer............. $avp(DstMediaIP):$avp(MediaProfileID):$var(proxy):$var(newaddr):\n");
    };

    t_on_reply("LAN2WAN");

    if (!t_relay()) {
        xdbg("relay error $mb\n");
        sl_reply_error();
    };

    exit;
}

#Used for LAN PROFILE
onreply_route[LAN2WAN] {
    xdbg("Got Response $rs/ $fu/$ru/$si/$ci/$avp(rcv)\n");
    if (status =~ "(183)|2[0-9][0-9]") {
        if (has_body("application/sdp")) {
            $var(transcoding) = 0 ;
            xdbg("+++++++++++++++transcoding: $var(transcoding)++++++++++\n");
            rtpproxy_answer("of","$avp(SrcMediaIP)","$avp(MediaProfileID)");
        };

        # Is this a transaction behind a NAT and we did not
        # know at time of request processing?
    } 

    if (nat_uac_test("1")) {
        fix_nated_contact();
    };
}

failure_route[LAN2WAN] {
    if (t_was_cancelled()) {
        rtpproxy_unforce("$avp(MediaProfileID)");
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
    xlog("Failed $rs\n");
}
