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

    if($DLG_dir) {
        $avp(DLG_dir) = $DLG_dir ;
    } else {
        $avp(DLG_dir) = "upstream" ;
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
            xlog("L_INFO", "BLOX_DBG::: blox-lan2wan.cfg: No profile configured for $avp(MediaProfileID): $avp(MediaProfile)\n");
            sl_send_reply("500","Internal Server error");
            exit;
        }

        $avp(MediaTranscoding) = $(avp(MediaProfile){param.value,TRANSCODING});
        $avp(MediaNAT) = $(avp(MediaProfile){param.value,NAT});
        if($avp(MediaTranscoding) == "1") {
            route(MTS_LAN2WAN);
            exit ;
        }

        $avp(setid) = $(avp(MediaProfileID){s.int}) ;

        if(is_dlg_flag_set("DLG_FLAG_TRANSCODING")) {
            rtpengine_delete();
        }

        $avp(ROUTE_DIR) = "INT2EXT" ;
        route(HANDLE_MEDIA_ROUTE) ;
    };

    #FIXME: performance on db needs to be optimized
    #Clearing the cfgparam used for T38
    #$avp(cfgparam) = "cfgparam" ;
    #avp_db_delete("$hdr(call-id)","$avp($avp(cfgparam))") ;

    t_on_reply("LAN2WAN");
    t_on_failure("LAN2WAN");

    if(has_totag()) { #Within dialog
        $var(duparams) = null ;
        if($du != null && $du != "") {
            $var(du) = $du ; #orginal
            $var(duparams) = $(var(du){uri.params}) ;
        }
        xdbg("BLOX_DBG::: blox-lan2wan.cfg: du: $var(du): $var(duparams)\n");
        if($avp(DLG_dir) == "downstream" && $dlg_val(dcontact)) {
            if($var(duparams) && $(var(duparams){param.exist,lr}) == 1) {
                $ru = $dlg_val(dcontact) ;
            } else {
                $du = $dlg_val(dcontact) ;
            }
        }
        if($avp(DLG_dir) == "upstream" && $dlg_val(ucontact)) {
            if($var(duparams) && $(var(duparams){param.exist,lr}) == 1) {
                $ru = $dlg_val(ucontact) ; 
            } else {
                $du = $dlg_val(ucontact) ;
            }
        }
    }

    if(($Ri == $si)) {
        if($du != null && $du != "") {
            $var(du) = $du ; #orginal
            $var(duuri) = "sip:" + $(var(du){uri.host}) + ":" + $(var(du){uri.port}) ;
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

    xlog("L_INFO", "BLOX_DBG::: blox-lan2wan.cfg: ROUTING $rm - dir: $avp(DLG_dir) $DLG_dir: from: $fu src:$si:$sp to ru:$ru : down: $avp(dcontact) up:$avp(ucontact) -> dst: $du \n");

    if($var(SHMPACT)) {
        route(SIP_HEADER_MANIPULATE,$var(SHMPACT));
    } 

    if (!t_relay()) {
        xlog("L_ERR", "BLOX_DBG::: blox-lan2wan.cfg: Relay error $mb\n");
        sl_reply_error();
    };

    exit;
}

#Used for LAN PROFILE
onreply_route[LAN2WAN] {
    xlog("L_INFO","BLOX_DBG::: blox-lan2wan.cfg: Got Response code:$rs from:$fu ru:$ru src:$si:$sp callid:$ci rcv:$Ri:$Rp\n");

    if (status =~ "(18[03])|2[0-9][0-9]") {
        if (has_body("application/sdp")) {
            route(HANDLE_MEDIA_REPLY); 
        }

        if(is_method("INVITE")) {
            if(nat_uac_test("96")) { # /* If Contact not same as source IP Address */
                $var(cturi) = $ct.fields(uri) ;
                $var(cthost) = $(var(cturi){uri.host}) ;
                $var(ctparams) = $ct.fields(params) ;
                if(is_ip_rfc1918("$var(cthost)") && !is_ip_rfc1918("$si")) { # /* Set Source IP, Source is not Priviate IP */
                    xlog("L_INFO","BLOX_DBG::: blox-lan2wan.cfg: $avp(DLG_dir) $DLG_dir | Set Source IP, Source is not Priviate IP and received!=via  $si:$sp;$var(ctparams) ct:$var(cthost)\n");
                    if($avp(DLG_dir) == "downstream") {
                        $dlg_val(dcontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    } else {
                        $dlg_val(ucontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    }
                } else { # /* Set 200 OK Contact */
                    $dlg_val(rcv) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    xdbg("BLOX_DBG::: blox-lan2wan.cfg: $ct ==> $var(cthost) <==> $Ri : $dlg_val(loop)\n");
                    xdbg("BLOX_DBG::: blox-lan2wan.cfg: $avp(DLG_dir) $DLG_dir | Set Source IP, Source is Priviate IP and received!=via  $si:$sp;$var(ctparams)\n");
                    xdbg("BLOX_DBG::: blox-lan2wan.cfg: Set 200 OK Contact $ct.fields(uri)\n");
                    if($avp(DLG_dir) == "downstream") {
                        #nofix param is for roaming user NAT resolved
                        if($(dlg_val(dcontact){uri.param,nofix}) == "1") {
                            xlog("L_INFO", "BLOX_DBG::: blox-lan2wan.cfg: Don't fix dcontact -> $dlg_val(dcontact) <-\n");
                        } else {
                            $dlg_val(dcontact) = $ct.fields(uri) ;
                        }
                    } else {
                        $dlg_val(ucontact) = $ct.fields(uri) ;
                    }
                }
                xlog("L_INFO", "BLOX_DBG::: blox-lan2wan.cfg: $ct != $si Response to contact different source $DLG_dir -> $dlg_val(ucontact) -> $dlg_val(dcontact) <-\n");
            }
        }
    }
    if ($dlg_val(ep) && $dlg_val(ep) == "yes" && $avp(DLG_dir) == "downstream") {
        xdbg("BLOX_DBG::: blox-lan2wan.cfg: reply from endpoint:$dlg_val(ep): $avp(DLG_dir) fix nat");
        if(nat_uac_test("3")) {
            fix_nated_contact();
        }
    };
}

failure_route[LAN2WAN] {
    xlog("L_WARN","BLOX_DBG:::blox-lan2wan.cfg: Failed:$rm:$ru:$rs:$rr:LB:$avp(LBGID)\n");

    if (t_was_cancelled()) {
        rtpengine_delete();
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
}
#dnl vim: set ts=4 sw=4 tw=0 et :
