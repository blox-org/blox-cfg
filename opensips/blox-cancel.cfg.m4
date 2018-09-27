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


route[ROUTE_CANCEL] {
    if (method == "CANCEL") {
        xdbg("BLOX_DBG: SIP Method $rm received from $fu $si $sp to $ru\n");

        if($dlg_val(MediaProfileID)) {
            $avp(MediaProfileID) = $dlg_val(MediaProfileID) ;
        }

        if($avp(setid)) {
            rtpengine_delete();
            xlog("L_INFO", "BLOX_DBG: blox-cancel.cfg: Mediaprofile stopping the $avp(MediaProfileID)\n");
        }

        if($avp(DstMediaPort)) {
            $var(url) =  "http://127.0.0.1:8000" + "/unreservemediaports?local_rtp_port=" + $avp(DstMediaPort) ;
            xlog("L_INFO","BLOX_DBG: blox-cancel.cfg: Route: transcoding request : $var(url)\n");
            rest_get("$var(url)","$var(body)");
        }

        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        $avp(resource) = "resource" + "-" + $tt ;
        route(DELETE_ALLOMTS_RESOURCE);

        if($avp(LAN)) { #/* PBX to SBC */
            route(LAN2WAN);
        } else {
            route(WAN2LAN);
        }
    }
}
#dnl vim: set ts=4 sw=4 tw=0 et :
