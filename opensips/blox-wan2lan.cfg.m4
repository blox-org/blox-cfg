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


#Used for WAN Profiles
route[WAN2LAN] {
    if($dlg_val(MediaProfileID)) {
        $avp(MediaProfileID) = $dlg_val(MediaProfileID);
    }

    if (has_body("application/sdp")) {
        if(cache_fetch("local","$avp(MediaProfileID)",$avp(MediaProfile))) {
            xdbg("BLOX_DBG: blox-wan2lan.cfg: Loaded from cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else if (avp_db_load("$avp(MediaProfileID)","$avp(MediaProfile)/blox_profile_config")) {
            cache_store("local","$avp(MediaProfileID)","$avp(MediaProfile)");
            xdbg("BLOX_DBG: blox-wan2lan.cfg: Stored in cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else {
            xlog("L_INFO", "BLOX_DBG::: blox-wan2lan.cfg: No profile configured for $avp(MediaProfileID): $avp(MediaProfile)\n");
            sl_send_reply("500","Internal Server error");
            exit;
        }

        $avp(MediaTranscoding) = $(avp(MediaProfile){param.value,TRANSCODING});
        $avp(MediaNAT) = $(avp(MediaProfile){param.value,NAT});
        if($avp(MediaTranscoding) == "1") {
                route(MTS_WAN2LAN);
                exit ;
        }

        $avp(setid) = $(avp(MediaProfileID){s.int}) ;

        if(is_dlg_flag_set("DLG_FLAG_TRANSCODING")) {
            rtpengine_delete();
        }

        if(is_ip_rfc1918("$si") && $var(nat40)) {
            if($avp(MediaNAT) == "1") {
                rtpengine_offer("force publicif internal trust-address replace-origin replace-session-connection ICE=remove");
            } else {
                rtpengine_offer("force external internal trust-address replace-origin replace-session-connection ICE=remove");
            }
        } else {
            if($avp(MediaNAT) == "1") {
                rtpengine_offer("force publicif internal replace-origin replace-session-connection ICE=remove");
            } else {
                rtpengine_offer("force external internal replace-origin replace-session-connection ICE=remove");
            }
        }
    };

    #Clearing the cfgparam used for T38
    $avp(cfgparam) = "cfgparam" ;
    avp_db_delete("$hdr(call-id)","$avp($avp(cfgparam))") ;

    t_on_reply("WAN2LAN");
    t_on_failure("WAN2LAN");

    if(has_totag()) { #Within dialog
        if($DLG_dir == "downstream" && $dlg_val(dcontact)) {
            $du = $dlg_val(dcontact) ;
        }
        if($DLG_dir == "upstream" && $dlg_val(ucontact)) {
            $du = $dlg_val(ucontact) ;
        }
    }

    if(($Ri == $si)) {
        if($du != null && $du != "") {
            $var(du) = $du ; #orginal
            $var(duuri) = "sip:" + $(var(du){uri.host}) + $(var(du){uri.port}) ;
            $var(did) = $(var(du){uri.param,did}) ;
            if($var(did) == null || $var(did) == "") { 
                $var(did) = "" ;
            } else {
                $var(did) = ";did=" + $var(did) ;
            }

            subst("/Contact: +<sip:(.*)@(.*);did=(.*)>(.*)$/Contact: <$var(duuri)$var(did)>\4/");
        }
    }

    if(has_totag()) { #Within dialog
        if($du != null && $du != "") {
            $var(duri) = $du ;
            $var(fsock) = $fs ;
            $var(dsocket) = $(var(duri){uri.host}) ;
            $var(fsocket) = $(var(fsock){s.select,1,:}) ;
            if($var(dsocket) == $var(fsocket)) {
                $ru = $du ;
            }
        }
    }


    xlog("L_INFO", "BLOX_DBG::: blox-wan2lan.cfg: ROUTING $rm - dir: $DLG_dir: from: $fu src:$si:$sp to ru:$ru : down: $avp(dcontact) up:$avp(ucontact) -> dst: $du \n");
    if($var(SHMPACT)) {
        route(SIP_HEADER_MANIPULATE,$var(SHMPACT));
    } 
    if (!t_relay()) {
        xlog("L_ERR", "BLOX_DBG::: blox-wan2lan.cfg: Relay error $mb\n");
        sl_reply_error();
    };

    exit;
}

#Used for WAN PROFILE
onreply_route[WAN2LAN] {
    xlog("L_INFO","BLOX_DBG::: blox-wan2lan.cfg: Got Response code:$rs from:$fu ru:$ru src:$si:$sp callid:$ci rcv:$Ri:$Rp\n");
    remove_hf("User-Agent");
    insert_hf("User-Agent: USERAGENT\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT\r\n","CSeq") ;
    }

    if (status =~ "(183)|2[0-9][0-9]") {
        if (has_body("application/sdp")) {
            $var(transcoding) = 0 ;
            if(is_ip_rfc1918("$si") && nat_uac_test("40")) {
                if($avp(MediaNAT) == "1") {
                    rtpengine_answer("force internal publicif trust-address replace-origin replace-session-connection ICE=remove");
                } else {
                    rtpengine_answer("force internal external trust-address replace-origin replace-session-connection ICE=remove");
                }
            } else {
                if($avp(MediaNAT) == "1") {
                    rtpengine_answer("force internal publicif replace-origin replace-session-connection ICE=remove");
                } else {
                    rtpengine_answer("force internal external replace-origin replace-session-connection ICE=remove");
                }
            }
        };

        if(is_method("INVITE")) {
            if(nat_uac_test("96")) { # /* If Contact not same as source IP Address */
                if(!is_ip_rfc1918("$si")) { # /* Set Source IP, Source is Priviate IP */
                    $var(ctparams) = $ct.fields(params) ;
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: $DLG_dir | Set Source IP, Source is Priviate IP and received!=via  $si:$sp;$var(ctparams)\n");
                    if($DLG_dir == "downstream") {
                        $dlg_val(ucontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    } else {
                        $dlg_val(dcontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    }
                } else { # /* Set 200 OK Contact */
                    $var(cturi) = $ct.fields(uri) ;
                    $var(cthost) = $(var(cturi){uri.host}) ;
                    $dlg_val(rcv) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: $ct ==> $var(cthost) <==> $Ri : $dlg_val(loop)\n");
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: $DLG_dir | Set Source IP, Source is Priviate IP and received!=via  $si:$sp;$var(ctparams)\n");
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: Set 200 OK Contact $ct.fields(uri)\n");
                    if($DLG_dir == "downstream") {
                        $dlg_val(ucontact) = $ct.fields(uri) ;
                    } else {
                        $dlg_val(dcontact) = $ct.fields(uri) ;
                    }
                }
                xlog("L_INFO", "BLOX_DBG::: blox-wan2lan.cfg: $ct != $si Response to contact different source $DLG_dir -> $dlg_val(ucontact) -> $dlg_val(dcontact) <-\n");
            }
        }
    }

    if (nat_uac_test("3")) {
        fix_nated_contact();
    };
}

failure_route[WAN2LAN] {
    if (t_was_cancelled()) {
        rtpengine_delete();
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
    xlog("L_WARN", "BLOX_DBG::: blox-wan2lan.cfg: Failed $rs\n");
}
