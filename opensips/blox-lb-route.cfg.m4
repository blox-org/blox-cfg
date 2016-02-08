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

route[BLOX_LB_CFG]
{
    $var(LBID) = $param(1);
    $var(LB) = $param(2);
    $var(match) = $(var(LB){param.value,cond});
    $var(params) = $(var(LB){param.value,params});
    $var(pat) = $(var(LB){param.value,pattern});
    $var(regexp) = "/\,/;/g";
    $var(params) = $(var(params){re.subst,$var(regexp)});    

    xlog("BLOX_DBG::: params $var(params) pat $var(pat) matching condition $var(match)\n");
    if($var(match) && $var(pat) && $var(params)) {
        route(READ_HEADER,$var(match)); 
	if($var(HEADER) && (pcre_match("$var(HEADER)","$var(pat)"))) {
            xlog("BLOX_DBG::: $var(HEADER) matched $var(pat)\n");
            $var(grpid) = $(var(LBID){s.int});      
            if ( !load_balance("$var(grpid)","$var(params)")) {
                send_reply("500","Service full");
                exit;
            }
        } else {    
            xlog("BLOX_DBG::: No patterns matched, falling back to default route");
        }
    } else {
        xlog("BLOX_DBG::: :$var(match):$var(pat):$var(pat): No patterns matched, falling back to default route");
    } 
}
