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
            xdbg("BLOX_DBG: Loaded from cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else if (avp_db_load("$avp(MediaProfileID)","$avp(MediaProfile)/blox_profile_config")) {
            cache_store("local","$avp(MediaProfileID)","$avp(MediaProfile)");
            xdbg("BLOX_DBG: Stored in cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else {
            xlog("L_INFO", "BLOX_DBG::: No profile configured for $avp(MediaProfileID): $avp(MediaProfile)\n");
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

        if(is_ip_rfc1918("$si") && nat_uac_test("40")) {
            rtpengine_offer("force internal external trust-address replace-origin replace-session-connection");
        } else {
            rtpengine_offer("force internal external replace-origin replace-session-connection");
        }
    };

    t_on_reply("LAN2WAN");
    t_on_failure("LAN2WAN");

    if($DLG_dir == "downstream" && $dlg_val(dcontact)) {
        $du = $dlg_val(dcontact) ;
    }
    if($DLG_dir == "upstream" && $dlg_val(ucontact)) {
        $du = $dlg_val(ucontact) ;
    }

    xlog("L_INFO", "BLOX_DBG::: ROUTING SIP Method $rm received from $fu $si $sp to $ru $avp(contact) : $du \n");

    if (!t_relay()) {
        xlog("L_ERR", "LAN_2_WAN Relay error $mb\n");
        sl_reply_error();
    };

    exit;
}

#Used for LAN PROFILE
onreply_route[LAN2WAN] {
    xdbg("BLOX_DBG::: Got Response $rs/ $fu/$ru/$si/$ci/$avp(rcv)\n");
    if (status =~ "(183)|2[0-9][0-9]") {
        if (has_body("application/sdp")) {
            $var(transcoding) = 0 ;
            if(is_ip_rfc1918("$si") && nat_uac_test("40")) {
                rtpengine_answer("force external internal trust-address replace-origin replace-session-connection");
            } else { 
                rtpengine_answer("force external internal replace-origin replace-session-connection");
            }
        };

        if(is_method("INVITE")) {
            if(nat_uac_test("96")) { # /* If Contact not same as source IP Address */
                if(is_ip_rfc1918("$si") && nat_uac_test("2")) { # /* Set Source IP, Source is Priviate IP and received!=via */
                    $var(ctparams) = $ct.fields(params) ;
                    xlog("L_INFO", "BLOX_DBG::: Set Source IP, Source is Priviate IP and received!=via  $si:$sp;$var(ctparams)\n");
                    if($DLG_dir == "downstream") {
                        $dlg_val(ucontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    } else {
                        $dlg_val(dcontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    }
                } else { # /* Set 200 OK Contact */
                    xlog("L_INFO", "BLOX_DBG::: Set 200 OK Contact ct.fields(uri)\n");
                    if($DLG_dir == "downstream") {
                        $dlg_val(ucontact) = $ct.fields(uri) ;
                    } else {
                        $dlg_val(dcontact) = $ct.fields(uri) ;
                    }
                }
                xlog("L_INFO", "BLOX_DBG::: $ct != $si Response to contact different source $DLG_dir -> $dlg_val(ucontact) -> $dlg_val(dcontact) <-\n");
            }
        }
    }

    if (nat_uac_test("3")) {
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
    xlog("L_WARN", "Failed $rs\n");
}
