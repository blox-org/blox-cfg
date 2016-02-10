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


mpath="MODULE_PATH"

loadmodule "db_mysql.so"
loadmodule "signaling.so"
loadmodule "sl.so"
loadmodule "tm.so"
loadmodule "rr.so"
loadmodule "maxfwd.so"
loadmodule "textops.so"
loadmodule "usrloc.so"
loadmodule "registrar.so"
loadmodule "mi_fifo.so"
loadmodule "uri.so"
loadmodule "nathelper.so"
loadmodule "nat_traversal.so"
loadmodule "sipmsgops.so"
loadmodule "dialog.so"
loadmodule "diversion.so"
loadmodule "json.so"
loadmodule "drouting.so"
loadmodule "cfgutils.so"
loadmodule "acc.so"
loadmodule "avpops.so"
loadmodule "path.so"
loadmodule "cachedb_local.so"

loadmodule "uac_auth.so"
loadmodule "uac_registrant.so"
loadmodule "uac.so"
loadmodule "auth.so"
loadmodule "auth_db.so"

loadmodule "rtpengine.so"
loadmodule "rest_client.so"

loadmodule "regex.so"
loadmodule "enum.so"
loadmodule "ipops.so"
loadmodule "userblacklist.so"
loadmodule "load_balancer.so"
loadmodule "pua.so"
loadmodule "pua_mi.so"

loadmodule "event_datagram.so"

