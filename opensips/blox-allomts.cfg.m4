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

route[DELETE_ALLOMTS_RESOURCE] {
    if(avp_db_load("$hdr(call-id)","$avp($avp(resource))")) {
        #route(DISCONNECT_ALLOMTS_RESOURCE); #DISCONNECT NOT REQUIRED (OPTIONAL)
        $var(url) = null;

        $json(res) := $avp($avp(resource));
        $var(idx) = $json(res/VT-Index) ;
        if($var(idx) != null) {
            xdbg("VT Index: $var(idx)\n");
            $var(resource) = "{ \"VT-Index\": " + $var(idx) + " }" ;
            $var(url) = "gMTSSRV" + "/delete?resource=" + $var(resource);
        }

        $var(idx) = null; #below fail to replace value to null, init here must
        $var(idx) = $json(res/CPP-Index) ;
        if($var(idx) != null) {        
            xdbg("CPP Index: $var(idx)\n");
            $var(idx) = $json(res/CPP-Index) ;
            $var(resource) = "{ \"CPP-Index\": " + $var(idx) + " }" ;
            $var(url) = "gMTSSRV" + "/stoppassthrough?resource=" + $var(resource);
        }

        xdbg("Route DELETE_ALLOMTS_RESOURCE $avp(resource) -> $avp($avp(resource)) : Connecting $var(url)\n");
        if(!rest_post("$var(url)", "$fU", "text/plain", "$var(body)", "$var(ct)", "$var(rcode)")) {
            xdbg("######################Unable to contact transcoding server $ru from $si : $sp" );
        };
        xdbg("##############Got Response $var(body)\n");
        avp_db_delete("$hdr(call-id)","$avp($avp(resource))");
    }
}

route[CONNECT_ALLOMTS_RESOURCE] {
    $avp(resource1) = "resource" + "-" + $ft ;
    if(avp_db_load("$hdr(call-id)","$avp($avp(resource1))")) {
        $json(res) := $avp($avp(resource1));
        $var(idx) = $json(res/VT-Index) ;
        $var(resource1) = "{ \"VT-Index\": " + $var(idx) + " }" ;
    } else {
        xlog("L_WARN", "didnt find $avp(resource1)\n");
    }

    xdbg("Got $var(resource1)\n");

    $avp(resource2) = "resource" + "-" + $tt ;
    if(avp_db_load("$hdr(call-id)","$avp($avp(resource2))")) {
        $json(res) := $avp($avp(resource2));
        $var(idx) = $json(res/VT-Index) ;
        $var(resource2) = "{ \"VT-Index\": " + $var(idx) + " }" ;
    } else {
        xlog("L_WARN", "didnt find $avp(resource2)\n");
    }

    xdbg("Got $var(resource2)\n");

    $var(url) = "gMTSSRV" + "/connect?resourceA=" + $var(resource1) + "&resourceB=" + $var(resource2);

    xdbg("Connecting $var(url)\n");
    if(!rest_post("$var(url)", "$fU", "text/plain", "$var(body)", "$var(ct)", "$var(rcode)")) {
        xlog("L_WARN", "######################Unable to contact transcoding server $ru from $si : $sp" );
    };

    xdbg("##############Got Response $var(body)\n");
}

route[DISCONNECT_ALLOMTS_RESOURCE] {
    $avp(resource1) = "resource" + "-" + $ft ; #/* Dont use $avp(resource) should be used for only route[DELETE_ALLOMTS_RESOURCE] */
    if(avp_db_load("$hdr(call-id)","$avp($avp(resource1))")) {
        $json(res) := $avp($avp(resource1));
        $var(idx) = $json(res/VT-Index) ;
        $var(resource1) = "{ \"VT-Index\": " + $var(idx) + " }" ;
    } else {
        xlog("L_WARN", "didnt find $avp(resource1)\n");
    }

    xdbg("Got $var(resource1)\n");

    $avp(resource2) = "resource" + "-" + $tt ;
    if(avp_db_load("$hdr(call-id)","$avp($avp(resource2))")) {
        $json(res) := $avp($avp(resource2));
        $var(idx) = $json(res/VT-Index) ;
        $var(resource2) = "{ \"VT-Index\": " + $var(idx) + " }" ;
    } else {
        xlog("L_WARN", "didnt find $avp(resource2)\n");
    }

    xdbg("Got $var(resource2)\n");

    $var(url) = "gMTSSRV" + "/disconnect?resourceA=" + $var(resource1) + "&resourceB=" + $var(resource2);

    xdbg("Connecting $var(url)\n");
    if(!rest_post("$var(url)", "$fU", "text/plain", "$var(body)", "$var(ct)", "$var(rcode)")) {
        xlog("L_WARN", "######################Unable to contact transcoding server $ru from $si : $sp" );
    };

    xdbg("##############Got Response $var(body)\n");
}
