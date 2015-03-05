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
    insert_hf("User-Agent: USERAGENT-MAJORVERSION.MINORVERSION.REVNUMBER-RELEASE\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT-MAJORVERSION.MINORVERSION.REVNUMBER-RELEASE\r\n","CSeq") ;
    }

    if($dlg_val(MediaProfileID)) {
        $avp(MediaProfileID) = $dlg_val(MediaProfileID);
    }

    if (has_body("application/sdp")) {
        if(cache_fetch("local","$avp(MediaProfileID)",$avp(MediaProfile))) {
            xdbg("Loaded from cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else if (avp_db_load("$avp(MediaProfileID)","$avp(MediaProfile)/blox_profile_config")) {
            cache_store("local","$avp(MediaProfileID)","$avp(MediaProfile)");
            xdbg("Stored in cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else {
            xlog("L_INFO", "No profile configured for $avp(MediaProfileID): $avp(MediaProfile)\n");
            sl_send_reply("500","Server error\n");
            exit;
        }

        $avp(MediaLANIP) = $(avp(MediaProfile){param.value,LAN});
        if($avp(WANADVIP)) {
            $avp(MediaWANIP) = $avp(WANADVIP) ;
        } else {
            $avp(MediaWANIP) = $(avp(MediaProfile){param.value,WAN});
        }
        $avp(MediaTranscoding) = $(avp(MediaProfile){param.value,TRANSCODING});
        #$avp(MediaTranscoding) = 0;

        if(is_dlg_flag_set("DLG_FLAG_TRANSCODING")) {
            rtpproxy_unforce("$avp(MediaProfileID)");
        }

        if(is_dlg_flag_set("DLG_FLAG_LAN2WAN")) { #Org Call Intiated from LAN2WAN
                if($DLG_dir == "downstream") { /* Set aprop. LAN WAN Media IP */
                    $avp(DstMediaIP) = $avp(MediaWANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaLANIP) ;
                } else {
                    $avp(DstMediaIP) = $avp(MediaLANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaWANIP) ;
                }
        } else { #Should be Re-Invite from LAN2WAN
                if($DLG_dir == "downstream") { /* Set aprop. LAN WAN Media IP */
                    $avp(DstMediaIP) = $avp(MediaLANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaWANIP) ;
                } else {
                    $avp(DstMediaIP) = $avp(MediaWANIP) ;
                    $avp(SrcMediaIP) = $avp(MediaLANIP) ;
                }
        }

        rtpproxy_offer("o","$avp(DstMediaIP)","$avp(MediaProfileID)","$var(proxy)","$var(newaddr)");
        xdbg("Route: rtpproxy_offer............. $avp(DstMediaIP):$avp(MediaProfileID):$var(proxy):$var(newaddr):\n");

        if($avp(MediaTranscoding) == "1") {
            $avp(AUDIOCodec) = "MEDIA:" + $avp(MediaProfileID) ;
            if(cache_fetch("local","$avp(AUDIOCodec)",$avp(AUDIOCodec))) {
                xdbg("Loaded from cache $avp(AUDIOCodec): $avp(AUDIOCodec)\n");
            } else if (avp_db_load("$avp(AUDIOCodec)","$avp(AUDIOCodec)/blox_config")) {
                cache_store("local","$avp(AUDIOCodec)","$avp(AUDIOCodec)");
                xdbg("Stored in cache $avp(AUDIOCodec): $avp(AUDIOCodec)\n");
            }

            #$avp(AUDIOCodec) = "0:20" ;

            $var(tDstMediaPort) = $(var(newaddr){s.select,1,:}) ;
            xdbg("Route: rtpproxy_offer............. $var(tDstMediaPort)\n");

            $avp(DstMediaPort) = $(var(tDstMediaPort){s.int}) ;
            if(is_direction("upstream")) { #Direction calculated in route
                xdbg("Route: upstream($DLG_dir)\n");
                $avp(SrcMediaPort) = ($avp(DstMediaPort) + gMediaPortOffset);
            } else {
                xdbg("Route: downstream($DLG_dir)\n");
                $avp(SrcMediaPort) = ($avp(DstMediaPort) - gMediaPortOffset);
            }
    
            $var(oline) = $(rb{sdp.line,o});
            $var(mline) = $(rb{sdp.line,m});
            $var(cline) = $(rb{sdp.line,c});

            $var(osource) = $(var(oline){s.select,5, });
            $var(mport) = $(var(mline){s.select,1, });
            $var(mtype) = $(var(mline){s.select,2, });
            $var(t38) = $(var(mline){s.select,3, });

            if($var(mtype) == "udptl" && $var(t38) == "t38") {
                $avp(SrcUdptl) = 1;
                $avp(SrcT38) = 1;

                #$avp(T38FaxVersion) = "0";
                #$avp(T38MaxBitRate) = "9600";
                #$avp(T38FaxFillBitRemoval) = "false"; #This will be replaced if passed
                #$avp(T38FaxRateManagement) = "transferredTCF";
                #$avp(T38FaxMaxDatagram) = "1400";
                #$avp(T38FaxUdpEC) = "t38UDPRedundancy";

                $var(i) = 0;
                $var(aline) = $(rb{sdp.line,a,$var(i)});
                $avp(rSrcT38Param) = null;
                while($var(aline)) {
                    $var(aline) = $(var(aline){s.substr,2,0}) ;
                    if($var(i)) {
                        $avp(rSrcT38Param) = $avp(rSrcT38Param) + ";" + $var(aline) ;
                    } else {
                        $avp(rSrcT38Param) = $avp(rSrcT38Param) + $var(aline) ;
                    }

                    xdbg("------------------ $var(rSrcT38Param) ------------\n");
                    $var(i) = $var(i) + 1;
                    $var(aline) = $(rb{sdp.line,a,$var(i)});
                }
                $avp(rSrcT38Param) = $(avp(rSrcT38Param){re.subst,/:/=/g}) ;
            }
    
            $avp(rSrcMediaIP) = $(var(cline){s.select,2, });
            $avp(rSrcMediaPort) = $var(mport);
            $avp(rSrcCodec) = null;
            xdbg("------------------ $avp(rSrcMediaIP):$avp(rSrcMediaPort):$avp(rSrcCodec) -------- :$avp(SrcMediaPort):$avp(DstMediaPort):\n");

            #Supported Codec
            $avp(18) = "g729";
            $avp(0) = "g711u";
            $avp(8) = "g711a";

            $var(jCodec)   := '{
                        "g711u":  { "id": "0",  "codec": "g711u", "rtpmap": "a=rtpmap:0 PCMU/8000", "ptime": 20, "maxptime": 60 },
                        "g729":   { "id": "18", "codec": "g729",  "rtpmap": "a=rtpmap:18 G729/8000", "ptime": 20, "maxptime": 60 },
                        "g711a":  { "id": "8",  "codec": "g711a", "rtpmap": "a=rtpmap:8 PCMA/8000", "ptime": 20, "maxptime": 60 }
            }';
            $json(jCodec)   := $var(jCodec);

            xdbg("------------------ $json(jCodec)-----------------------\n");

            $var(i) = 3;
            $var(j) = 0;
            $var(mcodec) = $(var(mline){s.select,$var(i), });

            $json(jCodecList) := "{}" ; #jCodecList used for hash manipulation to avoid codec duplication added to rSrcCodec[]
            while($var(mcodec)) {
                xdbg("------------------$var(mcodec)-----------------------\n");
                if($avp($var(mcodec))) {
                    $var(codec) = $avp($var(mcodec)) ;
                    xdbg("Adding >>>>>>------------------$var(codec)-----------------------\n");
                    xdbg("Got codec $var(mcodec) $var(codec)\n");
                    avp_insert("$avp(rSrcCodec)","$var(codec)","100");
                    $json(jCodecList/$var(codec)) = $json(jCodec/$var(codec)) ;
                }
                $var(i) = $var(i) + 1;
                $var(mcodec) = $(var(mline){s.select,$var(i), });
            }
            xdbg("Remote Src codec list $(avp(rSrcCodec)[0]) $(avp(rSrcCodec)[1])\n");

            xdbg("------------------$json(jCodecList)-----------------------\n");

            $var(i) = 0;
            $var(mcodec) = $(avp(AUDIOCodec){s.select,$var(i),;});
            $var(mcodec) = $(var(mcodec){s.select,0,:}) ;
            $avp(rSrcTransCodec) = null;
            while($var(mcodec)) {
                xdbg("------------------$var(mcodec)-----------------------\n");
                if($avp($var(mcodec))) {
                    $var(codec) = $(avp($var(mcodec)){s.select,0,:}) ;
                    xdbg("Got codec $var(mcodec) $var(codec)\n");
                    if($json(jCodecList/$var(codec)) == null) {
                        xdbg("Adding >>>>>>------------------$var(codec)-----------------------\n");
                        avp_insert("$avp(rSrcTransCodec)","$var(codec)","100");
                        $json(jCodecList/$var(codec)) = $json(jCodec/$var(codec)) ;
                    }
                }
                $var(i) = $var(i) + 1;
                $var(mcodec) = $(avp(AUDIOCodec){s.select,$var(i),;});
                $var(mcodec) = $(var(mcodec){s.select,0,:}) ;
            }

            $avp(resource) = "resource" + "-" + $ft ;
            route(DELETE_ALLOMTS_RESOURCE); #Delete previous session, if any
    
            if($avp(MediaSessId)) {
            } else {
                $avp(MediaSessId) = ($Ts/1000)*1234;
            }

            #$var(sdp) = $(rb{sdp.line,v}) + "\r\n" ;

            $var(sdp) = "v=0\r\n" ;
            $var(sdp) = $var(sdp) + "o=- " + $avp(MediaSessId) + " " + $avp(MediaSessId) + " IN IP4 " + $avp(DstMediaIP) + "\r\n";
            $var(sdp) = $var(sdp) + $(rb{sdp.line,s}) + "\r\n" ;
            $var(sdp) = $var(sdp) + "c=IN IP4 " + $avp(DstMediaIP) + "\r\n";
            $var(sdp) = $var(sdp) + $(rb{sdp.line,t}) + "\r\n" ;

            $var(i) = 0;
            $var(rScodec) = $(avp(rSrcCodec)[$var(i)]) ;
            $var(codecids) = "" ;
            $var(rtpmaps) = "" ;
            while($var(rScodec)) {
                $json(rjCodec) := $json(jCodec/$var(rScodec)) ;
                $var(codecids) = $var(codecids) + $json(rjCodec/id) + " ";
                $var(rtpmaps) = $var(rtpmaps) + $json(rjCodec/rtpmap) + "\r\n";
                
                $var(rScodec) = null;

                $var(i) = $var(i) + 1; 
                if($(avp(rSrcCodec)[$var(i)])) {
                    $var(rScodec) = $(avp(rSrcCodec)[$var(i)]) ;
                }
            }

            $var(i) = 0;
            $var(rScodec) = $(avp(rSrcTransCodec)[$var(i)]) ;
            while($var(rScodec)) {
                $json(rjCodec) := $json(jCodec/$var(rScodec)) ;
                $var(codecids) = $var(codecids) + $json(rjCodec/id) + " ";
                $var(rtpmaps) = $var(rtpmaps) + $json(rjCodec/rtpmap) + "\r\n";
                
                $var(rScodec) = null;

                $var(i) = $var(i) + 1; 
                if($(avp(rSrcTransCodec)[$var(i)])) {
                    $var(rScodec) = $(avp(rSrcTransCodec)[$var(i)]) ;
                }
            }

            xdbg("------------------$var(rtpmaps):$var(codecids)-----------------------\n");

            if($avp(SrcT38)) {
                #GET T38Param from DB
                $avp(T38Param) = "T38FaxVersion:0;T38MaxBitRate:9600;T38FaxRateManagement:transferredTCF;T38FaxMaxDatagram:1400;T38FaxUdpEC:t38UDPRedundancy";
                $var(sdp) = $var(sdp) + "m=image " + $avp(DstMediaPort) + " udptl t38\r\n" ;
                $var(i) = 0;
                $var(t38attr) = $(avp(T38Param){s.select,$var(i),;}) ;
                while($var(t38attr)) {
                    $var(sdp) = $var(sdp) + "a=" + $var(t38attr) + "\r\n" ;
                    $var(i) = $var(i) + 1;
                    $var(t38attr) = $(avp(T38Param){s.select,$var(i),;}) ;
                }
                #Adding support for g711 termination for fax passthrough, if T38 not supported
                $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP " + "0 8\r\n" ;
            } else {
                $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP " + $var(codecids) + "101\r\n" ;
                $var(sdp) = $var(sdp) + $var(rtpmaps) + "a=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-16\r\na=ptime:20\r\na=sendrecv\r\n";
            }
        
            add_body("$var(sdp)","application/sdp");
        };
    };

    t_on_reply("LAN2WAN");

    if (!t_relay()) {
        xdbg("relay error $mb\n");
        sl_reply_error();
    };

    exit;
}

#Used for LAN PROFILE
onreply_route[LAN2WAN] {
    xdbg("Got Response $rs/ $fu/$ru/$si/$ci/$avp(rcv)\n");
    if (status =~ "(183)|2[0-9][0-9]") {
        if (has_body("application/sdp")) {
            $var(transcoding) = 0 ;
            xdbg("+++++++++++++++transcoding: $var(transcoding)++++++++++\n");
            rtpproxy_answer("o","$avp(SrcMediaIP)","$avp(MediaProfileID)");
        };

        # Is this a transaction behind a NAT and we did not
        # know at time of request processing?
    } 

    if (nat_uac_test("1")) {
        fix_nated_contact();
    };
}

failure_route[LAN2WAN] {
    if (t_was_cancelled()) {
        rtpproxy_unforce("$avp(MediaProfileID)");
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
    xlog("Failed $rs\n");
}
