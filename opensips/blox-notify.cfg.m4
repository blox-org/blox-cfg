route[ROUTE_NOTIFY] {
    if(method == "NOTIFY") {
        if($Ri == BLOX_NOTIFY_HOST && $Rp == BLOX_NOTIFY_PORT) { #Forward NOTIFY to Remote-Contact-Header
            loose_route();
            $var(remote) = $hdr(Remote-Contact-Header);
            $var(socket) = $hdr(Send-Socket);
            remove_hf("Remote-Contact-Header");
            remove_hf("Send-Socket");
            remove_hf("User-Agent");
            insert_hf("User-Agent: Blox-0.9.9-beta\r\n","CSeq") ;
            if(remove_hf("Server")) { #Removed Server success, then add ours
                insert_hf("Server: Blox-0.9.9-beta\r\n","CSeq") ;
            }
            $du = $var(remote);
            $fs = $var(socket);
            xlog("L_INFO","Sent NOTIFY to $var(remote) via $var(socket)\n") ;
            t_relay();
            exit ;
        } else if ((uri==myself || from_uri==myself)) { #Log only LAN NOTIFY
            if($avp(LAN)) { #Log only LAN side NOTIFY
                $var(body) = $avp(SIPProfile) + "\r\n" + $mb;
                rest_post("gNOTIFYSRV", "$var(body)", "text/plain", "$var(body)", "$var(ct)", "$var(rcode)");
                xlog("L_INFO","Sent NOTIFY to gNOTIFYSRV resp $var(body) $var(rcode)\n");
                sl_send_reply("200", "OK");
                exit;
            }
        }
        xlog("L_INFO", "SUBSCRIBE Unprocessed, Dropping SIP Method $rm received from $fu $si $sp to $ru ($avp(rcv))\n"); #/* Don't know what to do */
        drop();
        exit;
    }
}
