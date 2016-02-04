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

route[ROUTE_NOTIFY] {
    if(method == "NOTIFY") {
        if($Ri == "BLOX_NOTIFY_HOST" && $Rp == BLOX_NOTIFY_PORT) { #Forward NOTIFY to Remote-Contact-Header
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
