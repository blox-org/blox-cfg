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

        $avp(MediaTranscoding) = $(avp(MediaProfile){param.value,TRANSCODING});
        if($avp(MediaTranscoding) == "1") {
            route(MTS_LAN2WAN);
            exit ;
        }

        $avp(setid) = $(avp(MediaProfileID){s.int}) ;

        if(is_dlg_flag_set("DLG_FLAG_TRANSCODING")) {
            rtpengine_delete();
        }

        if(nat_uac_test("3")) {
            rtpengine_offer("force internal external replace-origin replace-session-connection");
        } else {
            rtpengine_offer("force internal external trust-address replace-origin replace-session-connection");
        }
    };

    t_on_reply("LAN2WAN");
    t_on_failure("LAN2WAN");

    $avp(contact) = $DLG_dir + "-contact";

    if($dlg_val($avp(contact))) {
        xlog("L_INFO","Send Request to $avp(contact) => $dlg_val($avp(contact))\n");
        $du = $dlg_val($avp(contact)) ;
    }

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
            if(nat_uac_test("3")) {
                rtpengine_answer("force external internal replace-origin replace-session-connection");
            } else { 
                rtpengine_answer("force external internal trust-address replace-origin replace-session-connection");
            }
        };
        if(is_method("INVITE")) {
            if(!nat_uac_test("3")) { #/* If Not behind NAT take contact from updated 200 OK */
                if($DLG_dir == "downstream") { #/* Set 200 OK Contact */
                    $avp(contact) = "upstream-contact";
                }
                if($DLG_dir == "upstream")   { #/* Set 200 OK Contact */
                    $avp(contact) = "downstream-contact";
                }
                $dlg_val($avp(contact)) = $ct.fields(uri) ;
            }
        }
    } 

    if (nat_uac_test("1")) {
        fix_nated_contact();
    };
}

failure_route[LAN2WAN] {
    if (t_was_cancelled()) {
        rtpengine_delete();
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
    xlog("Failed $rs\n");
}
