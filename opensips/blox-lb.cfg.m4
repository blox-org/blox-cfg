/* Blox is an Opensource Session Border Controller
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

route[BLOX_LOADBALANCE] {
    $var(lbret) = 0;    
    $var(uuid) = "LB" + $param(1);
    if($var(uuid)) {
        if(cache_fetch("local","$var(uuid)",$avp(LBMAP))) {
            xdbg("Loaded from cache $var(uuid): $avp(LBMAP)\n");
        } else if (avp_db_load("$var(uuid)","$avp(LBMAP)/blox_lb")) {
            cache_store("local","$var(uuid)","$avp(LBMAP)");
            xdbg("Stored in cache $var(uuid): $avp(LBMAP)\n");
        } else {
            $avp(LBMAP) = null;
            xlog("L_WARN", "BLOX_DBG::: Invaid LBMAP in blox load balanacer attribute $var(uuid)\n" );
            return(-1); 
        }
    }
    for ($var(LBMAPit) in $(avp(LBMAP)[*])) {
        $var(LBRuleid) = "LBRuleid:" + $(var(LBMAPit){s.select,0,,});
        $var(LBGID) = $(var(LBMAPit){s.select,1,,});
    
        if($var(LBRuleid)) {
            if(cache_fetch("local","$var(LBRuleid)",$avp(LBRule))) {
                xdbg("Loaded from cache $var(LBRuleid): $avp(LBRule)\n");
            } else if (avp_db_load("$var(LBRuleid)","$avp(LBRule)/blox_lb_rules")) {
                cache_store("local","$var(LBRuleid)","$avp(LBRule)");
                xdbg("Stored in cache $var(LBRuleid): $avp(LBRule)\n");
            } else {
                $avp(LBRule) = null;
                xlog("L_WARN", "BLOX_DBG::: Invaid LBRule in blox load balanacer attribute $var(LBRuleid)\n" );
            }
        }
   
        if($avp(LBRule)) {
            $var(cond) = $(var(LBMAPit){s.select,0,,});
            $var(lbres) = $avp(LBRule);
    
            if($var(cond)==""){$var(cond)=null;}
            if($var(lbres)==""){$var(lbres)=null;}

    
            if($var(cond) && $var(lbres)) {
                $var(regexp) = "/\,/;/g";
                $var(lbres) = $(var(lbres){re.subst,$var(regexp)}); #Table stores with ',' needs to be replaced with ';' to pass to load balancer

                route(LB_MATCH_CONDITION,$var(cond)); 
                xlog("BLOX_DBG::: lbres $var(lbres) cond $var(cond) $var(match)\n");
                if($var(match)) {
                    $var(LBGID) = $(var(LBGID){s.int});
                    if (load_balance("$var(LBGID)","$var(lbres)")) {
                        xlog("BLOX_DBG::: load_balance success with $var(LBGID)");
                        $var(lbret) = 1;   
                        return(1); 
                    } else {
                        xlog("BLOX_DBG::: load_balance failed with $var(LBGID)");
                    }
                } else {
                    xlog("BLOX_DBG::: pattern $var(HEADER) != $var(pat) not matched\n");
                }
            } else {
                xlog("L_WARN", "BLOX_DBG::: Invalid LBRule\n");
            }
        }
     
    }

    return(-1); 

}

route[LB_MATCH_CONDITION] {
	$var(match) = null;
include_file "blox-lb-rule-match-switch.cfg"
}


include_file "blox-lb-rule-match-routes.cfg"
