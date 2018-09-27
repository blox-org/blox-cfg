route[HANDLE_MEDIA_ROUTE] {
    if (has_body("application/sdp")) {
        if($avp(ROUTE_DIR) == "INT2EXT") {
            $var(dirNAT) = "internal publicif" ;
            $var(dir)    = "internal external" ;
        } else {
            $var(dirNAT) = "publicif internal" ;
            $var(dir)    = "external internal" ;
        }

        if(is_method("INVITE")) {
            reset_dlg_flag("DLG_FLAG_RTPOFFER");
        }

        #Media using Late binding (ACK with sdp)
        if(is_method("ACK") && is_dlg_flag_set("DLG_FLAG_RTPOFFER")) {
            if(is_ip_rfc1918("$si")) {
                if($avp(MediaNAT) == "1") {
                    if($var(nat32)) { #LAN-LAN Handled
                        rtpengine_answer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_answer("force $var(dirNAT) trust-address replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_answer("force $var(dir) trust-address replace-origin replace-session-connection ICE=remove");
                }
            } else {
                if($avp(MediaNAT) == "1") {
                    if($var(nat32) || $var(nat8)) {
                        rtpengine_answer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_answer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_answer("force $var(dir) replace-origin replace-session-connection ICE=remove");
                }
            }
            reset_dlg_flag("DLG_FLAG_RTPOFFER");
        } else {
            if(is_ip_rfc1918("$si")) {
                if($avp(MediaNAT) == "1") {
                    if($var(nat32)) { #LAN-LAN Handled
                        rtpengine_offer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_offer("force $var(dirNAT) trust-address replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_offer("force $var(dir) trust-address replace-origin replace-session-connection ICE=remove");
                }
            } else {
                if($avp(MediaNAT) == "1") {
                    if($var(nat32) || $var(nat8)) {
                        rtpengine_offer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_offer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_offer("force $var(dir) replace-origin replace-session-connection ICE=remove");
                }
            }
            set_dlg_flag("DLG_FLAG_RTPOFFER");
        }
    }
}

route[HANDLE_MEDIA_REPLY] {
    if (has_body("application/sdp")) {
        if($avp(ROUTE_DIR) == "INT2EXT") {
            $var(dirNAT) = "publicif internal" ;
            $var(dir)    = "external internal" ;
        } else {
            $var(dirNAT) = "internal publicif" ;
            $var(dir)    = "internal external" ;
        }

        if(is_dlg_flag_set("DLG_FLAG_RTPOFFER")) {
            if(is_ip_rfc1918("$si")) {
                if($avp(MediaNAT) == "1") {
                    if(nat_uac_test("32")) { #LAN-LAN NAT Handled
                        rtpengine_answer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_answer("force $var(dirNAT) trust-address replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_answer("force $var(dir) trust-address replace-origin replace-session-connection ICE=remove");
                }
            } else {
                if($avp(MediaNAT) == "1") {
                    if(nat_uac_test("40")) {
                        rtpengine_answer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_answer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_answer("force $var(dir) replace-origin replace-session-connection ICE=remove");
                }
            }
            reset_dlg_flag("DLG_FLAG_RTPOFFER");
        } else {
            if(is_ip_rfc1918("$si")) {
                if($avp(MediaNAT) == "1") {
                    if(nat_uac_test("32")) { #LAN-LAN NAT Handled
                        rtpengine_offer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_offer("force $var(dirNAT) trust-address replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_offer("force $var(dir) trust-address replace-origin replace-session-connection ICE=remove");
                }
            } else {
                if($avp(MediaNAT) == "1") {
                    if(nat_uac_test("40")) {
                        rtpengine_offer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove media-address=$si");
                    } else {
                        rtpengine_offer("force $var(dirNAT) replace-origin replace-session-connection ICE=remove");
                    }
                } else {
                    rtpengine_offer("force $var(dir) replace-origin replace-session-connection ICE=remove");
                }
            }
            set_dlg_flag("DLG_FLAG_RTPOFFER");
        }
    }
}
#dnl vim: set ts=4 sw=4 tw=0 et :
