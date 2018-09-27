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


#calculate concurrent call
route[OUTBOUND_CALL_ACCESS_CONTROL] {
    $var(setprofile) = 0;
    $var(channels) = $(avp(cac_uuid){uri.param,MAXOutbound}) ; 
    $var(channels) = $(var(channels){s.int});
    if($var(channels) == null) {
        $var(channels) = gMAX_OUTBOUND;
    }
    
    if(!isflagset(OUTBOUND_CALL_ACCESS_CONTROL)) {
        if($var(channels) > 0) {
            get_profile_size("outbound", "$avp(cac_uuid)", "$var(calls)");
            xdbg("BLOX_DBG: Call control: user '$avp(cac_uuid)' currently has '$var(calls)' of '$var(channels)' active calls before this one\n");
            if($var(calls) == null || ($var(calls) < $var(channels))) {
                xlog("L_INFO", "BLOX_DBG: blox-cac.cfg: Call control: user '$avp(cac_uuid)' currently has '$var(calls)' of '$var(channels)' active calls before this one\n");
                $var(setprofile) = 1;
            } else {
                xlog("L_WARN", "BLOX_DBG: blox-cac.cfg: Call control: user channel limit exceeded [$var(calls)/$var(channels)]\n");
                if(isflagset(487)) {
                    append_to_reply("X-Reason: Trunk channel limit exceeded\r\n");
                    sl_send_reply("487", "Request Terminated");
                    exit;
                }
            }
        }

        if($var(setprofile) > 0) { 
            create_dialog("PpB");
            set_dlg_profile("outbound","$avp(cac_uuid)");
            setflag(OUTBOUND_CALL_ACCESS_CONTROL);
        }
    }
}

route[INBOUND_CALL_ACCESS_CONTROL] {
    $var(setprofile) = 0;
    $var(channels) = $(avp(cac_uuid){uri.param,MAXInbound}) ; 
    $var(channels) = $(var(channels){s.int});
    if($var(channels) == null) {
        $var(channels) = gMAX_INBOUND;
    }
    
    if(!isflagset(INBOUND_CALL_ACCESS_CONTROL)) {
        if(($var(channels) && ($var(channels) > 0))) {
            get_profile_size("inbound", "$avp(cac_uuid)", "$var(calls)");
            if($var(calls) < $var(channels)) {
                xlog("L_INFO", "BLOX_DBG: blox-cac.cfg: Call control: user '$avp(cac_uuid)' currently has '$var(calls)' of '$var(channels)' active calls before this one\n");
                $var(setprofile) = 1;
            } else {
                xlog("L_WARN", "BLOX_DBG: blox-cac.cfg: Call control: user channel limit exceeded [$var(calls)/$var(channels)]\n");
                if(isflagset(487)) {
                    append_to_reply("X-Reason: Trunk channel limit exceeded\r\n");
                    sl_send_reply("487", "Request Terminated");
                    exit;
                }
            }
        }

        if($var(setprofile) > 0) { 
            create_dialog("PpB");
            set_dlg_profile("inbound","$avp(cac_uuid)");
            setflag(INBOUND_CALL_ACCESS_CONTROL);
        }
    }
}

#dnl vim: set ts=4 sw=4 tw=0 et :
