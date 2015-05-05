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


#Used for LAN Profiles
route[LAN2WAN] {
    remove_hf("User-Agent");
    insert_hf("User-Agent: USERAGENT\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT\r\n","CSeq") ;
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
            sl_send_reply("500","Internal Media Error");
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

                $var(i) = 0;
                $var(aline) = $(rb{sdp.line,a,$var(i)});
                $avp(rSrcT38Param) = null;
                while($var(aline)) {
                    $var(aline) = $(var(aline){s.substr,2,0}) ;
                    if($var(i) != 0) {
                        $avp(rSrcT38Param) = $avp(rSrcT38Param) + ";" + $var(aline) ;
                    } else {
                        $avp(rSrcT38Param) = $var(aline) ;
                    }

                    xdbg("------------------ $var(rSrcT38Param) ------------\n");
                    $var(i) = $var(i) + 1;
                    $var(aline) = $(rb{sdp.line,a,$var(i)});
                }
                $avp(rSrcT38Param) = $(avp(rSrcT38Param){re.subst,/:/=/g}) ;
            } else { #/* Parse SRTP Param*/
                $avp(rSrcSRTPParam) = null ;
                $avp(rSrcSRTPSDP) = null ;
                $avp(DstSRTPParam) = null ;
                $var(i) = 0;
                $var(aline) = $(rb{sdp.line,a,$var(i)});
                while($var(aline)) {
                    $var(aline) = $(var(aline){s.substr,2,0}) ;
                    $var(crypto) = $(var(aline){s.select,0,:}) ;
                    if($var(crypto) == "crypto") {
                        $var(param) = $(var(aline){s.select,1,:}) ;
                        $var(tag) = $(var(param){s.select,0, }) ;
                        $var(suite) = $(var(param){s.select,1, }) ;
                        $var(inline) = $(var(param){s.select,2, }) ;
                        if($var(inline) == "inline") {
                            $var(encoded) = $(var(aline){s.select,2,:}) ;
                            $var(decoded) = $(var(encoded){s.decode.base64}) ;
                            $var(hexenc) = $(var(decoded){s.encode.hexa}) ;
                            $var(rsrcmkey) = $(var(hexenc){s.substr,0,32});
                            $var(rsrcmsalt) = $(var(hexenc){s.substr,32,0});
                            $var(rSrcSRTPParam) = $var(suite) + ":" + $var(rsrcmkey) + ":" + $var(rsrcmsalt) + ":" + $var(encoded);
                            avp_insert("$avp(rSrcSRTPParam)","$var(rSrcSRTPParam)","10");
                            avp_insert("$avp(DstSRTPParam)","$var(rSrcSRTPParam)","10");
                            avp_insert("$avp(rSrcSRTPSDP)","$var(aline)","10");
                        }
                        xdbg("--$json(rSrcSRTPParam)---\n");
                    }
                    $var(i) = $var(i) + 1;
                    $var(aline) = $(rb{sdp.line,a,$var(i)});
                }
            }

            if($avp(rSrcSRTPParam) && ($avp(SrcSRTP) == SRTP_DISABLE)) {
                if($var(mtype) == "RTP/SAVP" ) {
                    xlog("L_WARN","LAN2WAN NOT ACCEPTABL HERE $avp(rSrcSRTPParam) <===> $avp(SrcMavp)\n");
                    sl_send_reply("488","Not Acceptable Here\n");
                    exit;
                }
            }
        
            if($avp(SrcSRTP) == SRTP_COMPULSORY) {
                if(($var(mtype) == "RTP/AVP" ) && (!$avp(rSrcSRTPParam))){
                    xlog("L_WARN"," LAN2WAN NOT ACCEPTABL HERE $avp(rSrcSRTPParam) <===> $avp(SrcMavp) <===> $avp(DstSRTP)\n");
                    sl_send_reply("488","Not Acceptable Here\n");
                    exit;
                }
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

            #xdbg("------------------ $json(jCodec)-----------------------\n");

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
    
            $var(SDPID1) = $(var(oline){s.select,1, });
            $var(SDPID2) = $(var(oline){s.select,2, });

            $var(sdp) = "v=0\r\n" ;
            $var(sdp) = $var(sdp) + "o=- " + $var(SDPID1) + " " + $var(SDPID2) + " IN IP4 " + $avp(DstMediaIP) + "\r\n";
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
                if(!$avp(T38Param)) {
                    $var(cfgparam) = "cfgparam" ;
                    if(avp_db_load("$hdr(call-id)","$avp($var(cfgparam))")) {
                        $var(param) = $(avp($var(cfgparam))) ;
                        $avp(T38Param) = $(var(param){uri.param,T38Param}) ;
                    } else {
                        xdbg("Error: LAN2WAN Loading cfgparam\n");
                    }
                }
                if($(avp(T38Param){s.int}) > 0) {
                    $avp(T38Param:1) = "MEDIA:" + $avp(MediaProfileID) ;
                    if(cache_fetch("local","$avp(T38Param:1)",$avp(T38Param:1))) {
                        xdbg("Loaded from cache $avp(T38Param:1): $avp(T38Param:1)\n");
                    } else if (avp_db_load("$avp(T38Param:1)","$avp(T38Param:1)/blox_config")) {
                        cache_store("local","$avp(T38Param:1)","$avp(T38Param:1)");
                        xdbg("Stored in cache $avp(T38Param:1): $avp(T38Param:1)\n");
                    }

                    $avp(SrcT38Param) = $avp(T38Param:1) ;

                    $var(sdp) = $var(sdp) + "m=image " + $avp(SrcMediaPort) + " udptl t38\r\n" ;
                    $var(i) = 0;
                    $var(t38attr) = $(avp(SrcT38Param){s.select,$var(i),;}) ;
                    while($var(t38attr)) {
                        $var(sdp) = $var(sdp) + "a=" + $var(t38attr) + "\r\n" ;
                        $var(i) = $var(i) + 1;
                        $var(t38attr) = $(avp(SrcT38Param){s.select,$var(i),;}) ;
                    }
                }
                #Adding support for g711 termination for fax passthrough, if T38 not supported
                $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP " + "0 8\r\n" ;
            } else {
                if($avp(rSrcSRTPParam)) {
                    if($avp(DstSRTP) == SRTP_OPTIONAL) {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP "  + $var(codecids) + "101\r\n" ;
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/SAVP " + $var(codecids) + "101\r\n" ;
                        
                        for ($var(aline) in $(avp(rSrcSRTPSDP)[*])) {
                            $var(sdp) = $var(sdp) + "a=" + $var(aline) + "\r\n";
                            xlog("------------- >...  $var(aline)");    
                        } 
                    } else if($avp(DstSRTP) == SRTP_COMPULSORY){
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/SAVP " + $var(codecids) + "101\r\n" ;
                        for ($var(aline) in $(avp(rSrcSRTPSDP)[*])) {
                            $var(sdp) = $var(sdp) + "a=" + $var(aline) + "\r\n";
                            xlog("------------- >...  $var(aline)");    
                        } 
                    } else {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP "  + $var(codecids) + "101\r\n" ;
                    }
                } else {
                    $avp(DstSRTPParam) = null ;
                    if($avp(DstSRTP) != SRTP_DISABLE) {
                        $var(dstrhexenc) = $(RANDOM{s.encode.hexa}) +  $(RANDOM{s.encode.hexa}) +  $(RANDOM{s.encode.hexa}) +  $(RANDOM{s.encode.hexa});
                        $var(dstmkey) = $(var(dstrhexenc){s.substr,0,32});
                        $var(dstmsalt) = $(var(dstrhexenc){s.substr,32,28});
                        $var(dstmkeysalt) = $var(dstmkey) + $var(dstmsalt);
                        $var(dstmkshexdec) = $(var(dstmkeysalt){s.decode.hexa});
                        $var(dstinline) = $(var(dstmkshexdec){s.encode.base64});

                        $var(DstSRTPParam) = "AES_CM_128_HMAC_SHA1_80:" + $var(dstmkey) + ":" + $var(dstmsalt) ;
                        avp_insert("$avp(DstSRTPParam)","$var(DstSRTPParam)","10");
                        $var(DstSRTPParam) = "AES_CM_128_HMAC_SHA1_32:" + $var(dstmkey) + ":" + $var(dstmsalt) ;
                        avp_insert("$avp(DstSRTPParam)","$var(DstSRTPParam)","10");
                        $var(DstSRTPParam) = "F8_128_HMAC_SHA1_80:" + $var(dstmkey) + ":" + $var(dstmsalt) ;
                        avp_insert("$avp(DstSRTPParam)","$var(DstSRTPParam)","10");
                    }


                    if($avp(DstSRTP) == SRTP_OPTIONAL) {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP "  + $var(codecids) + "101\r\n" ;
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/SAVP " + $var(codecids) + "101\r\n" ;
                        $var(sdp) = $var(sdp) + "a=crypto:1 " + "AES_CM_128_HMAC_SHA1_80" + " inline:" + $var(dstinline) + "\r\n" ;    
                        $var(sdp) = $var(sdp) + "a=crypto:2 " + "AES_CM_128_HMAC_SHA1_32" + " inline:" + $var(dstinline) + "\r\n" ;    
                        $var(sdp) = $var(sdp) + "a=crypto:3 " + "F8_128_HMAC_SHA1_80"     + " inline:" + $var(dstinline) + "\r\n" ;    
                    } else if($avp(DstSRTP) == SRTP_COMPULSORY) {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/SAVP " + $var(codecids) + "101\r\n" ;
                        $var(sdp) = $var(sdp) + "a=crypto:1 " + "AES_CM_128_HMAC_SHA1_80" + " inline:" + $var(dstinline) + "\r\n" ;    
                        $var(sdp) = $var(sdp) + "a=crypto:2 " + "AES_CM_128_HMAC_SHA1_32" + " inline:" + $var(dstinline) + "\r\n" ;    
                        $var(sdp) = $var(sdp) + "a=crypto:3 " + "F8_128_HMAC_SHA1_80"     + " inline:" + $var(dstinline) + "\r\n" ;    
                    } else {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/AVP "  + $var(codecids) + "101\r\n" ;
                    }

                }
                $var(sdp) = $var(sdp) + $var(rtpmaps) + "a=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-16\r\na=ptime:20\r\na=sendrecv\r\n";
            }

            add_body("$var(sdp)","application/sdp");
        };
    };

    t_on_reply("LAN2WAN");
    t_on_failure("LAN2WAN");

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
            $avp(rDstSRTPParam) = null ;
            $var(transcoding) = 0 ;
            $var(cryptoline) = null ;
            if($avp(MediaTranscoding) == "1") {
                $var(oline) = $(rb{sdp.line,o});
                $var(mline) = $(rb{sdp.line,m});
                $var(cline) = $(rb{sdp.line,c});
                $var(transcoding) = 1 ;

                $avp(mline) = null ;
                $var(i) = 0;
                $var(mline) = $(rb{sdp.line,m,$var(i)});
                xdbg("+++++++++++++++<<<<<type ------ $var(mline) ==> ++++++++++++++\n");
                while($var(mline)) {
                      avp_insert("$avp(mline)", "$var(mline)", "100"); 
                    xdbg("+++++++++++++++TYPE ------ $var(mline) ==> $(avp(mline)[$var(i)]) ++++++++++++++\n");
                    $var(i) = $var(i) + 1; 
                    $var(mline) = $(rb{sdp.line,m,$var(i)});
                }

                $var(osource) = $(var(oline){s.select,5, });
                $var(csource) = $(var(cline){s.select,2, });

                for ($var(mline) in $(avp(mline)[*])) {
                    $var(mport) = $(var(mline){s.select,1, });
                    $var(mtype) = $(var(mline){s.select,2, });
                    $var(t38) = $(var(mline){s.select,3, });
                    xdbg("+++++++++++++++type ------ $var(mline) ==> : $var(t38):$var(mtype):$var(mport) ++++++++++++++\n");
                    if($var(mtype) == "udptl" && $var(t38) == "t38") {
                        $avp(DstUdptl) = 1;
                        $avp(DstT38) = 1;
                        $avp(t38mline) = $var(mline) ;
    
                        $var(i) = 0;
                        $var(aline) = $(rb{sdp.line,a,$var(i)});
                        $var(rDstT38Param) = null ;
                        while($var(aline)) {
                            $var(aline) = $(var(aline){s.substr,2,0}) ;
                            if($var(i) != 0) {
                                $avp(rDstT38Param) = $avp(rDstT38Param) + ";" + $var(aline) ; 
                            } else {
                                $avp(rDstT38Param) = $var(aline) ;
                            }
                            xdbg("$var(aline) <<<<< ------------------ $avp(rDstT38Param) ------------\n");
                            $var(i) = $var(i) + 1;
                            $var(aline) = $(rb{sdp.line,a,$var(i)});
                        }
                        $avp(rDstT38Param) = $(avp(rDstT38Param){re.subst,/:/=/g}) ;
                    } else {
                        $avp(audiomline) = $var(mline) ;
                        $var(mcodec) = $(var(mline){s.select,3, });
                        $avp(18) = "g729";
                        $avp(0) = "g711u";
                        $avp(8) = "g711a";
                        $avp(g729) = 18;
                        $avp(g711u) = 0;
                        $avp(g711a) = 8;
                        $var(codec) = $avp($var(mcodec)) ;

                        $var(i) = 0;
                        $var(rScodec) = $(avp(rSrcCodec)[$var(i)]) ;
                        xdbg("+++++audio++++++++++$var(mcodec)>>>$var(codec)++++++++++\n");
                        while($var(rScodec)) {
                            xdbg("+++++++++++++++$var(codec) <==> $var(rScodec)++++++++++\n");
                            if($var(codec) == $var(rScodec)) {
                                $var(transcoding) = 0;
                            }
                            $var(rScodec) = null;
 
                            $var(i) = $var(i) + 1; 
                            if($(avp(rSrcCodec)[$var(i)])) {
                                $var(rScodec) = $(avp(rSrcCodec)[$var(i)]) ;
                            }
                        }

                        $var(i) = 0;
                        $var(aline) = $(rb{sdp.line,a,$var(i)});
                        while($var(aline)) {
                            $var(aline) = $(var(aline){s.substr,2,0}) ;
                            $var(crypto) = $(var(aline){s.select,0,:}) ;
                            if($var(crypto) == "crypto") {
                                $var(param) = $(var(aline){s.select,1,:}) ;
                                $var(tag) = $(var(param){s.select,0, }) ;
                                $var(suite) = $(var(param){s.select,1, }) ;
                                $var(inline) = $(var(param){s.select,2, }) ;
                                if($var(inline) == "inline") {
                                    $var(encoded) = $(var(aline){s.select,2,:}) ;
                                    $var(decoded) = $(var(encoded){s.decode.base64}) ;
                                    $var(hexenc) = $(var(decoded){s.encode.hexa}) ;
                                    $var(rdstmkey) = $(var(hexenc){s.substr,0,32});
                                    $var(rdstmsalt) = $(var(hexenc){s.substr,32,0});
                                    $var(rDstSRTPParam) = $var(suite) + ":" + $var(rdstmkey) + ":" + $var(rdstmsalt) + ":" + $var(encoded) ;
                                    avp_insert("$avp(rDstSRTPParam)","$var(rDstSRTPParam)","10");
                                    avp_insert("$avp(SrcSRTPParam)","$var(rDstSRTPParam)","10");
                                }
                                xdbg("--$json(rDstSRTPParam)---\n");
                            }
                            $var(i) = $var(i) + 1;
                            $var(aline) = $(rb{sdp.line,a,$var(i)});
                        }
                    }
                }
    
                xdbg("+++++++++++++++transcoding: $var(transcoding)+++++$avp(rDstT38Param)+++++\n");
                if($avp(SrcT38) && $avp(DstT38)) { #Must compare the param and bitrate as well
                    $var(transcoding) = 0; 
                    $var(mport) = $(avp(t38mline){s.select,1, });
                    $var(mtype) = $(avp(t38mline){s.select,2, });
                    $var(t38) = $(avp(t38mline){s.select,3, });
                } else {
                    if(($var(transcoding) == 0) && $avp(rSrcSRTPParam) && $avp(rDstSRTPParam)) {
                        xdbg("+++++++++++++++SRTP testing : $var(transcoding)+++++$avp(rDstSRTPParam)+++++\n");
                    } else {
            if($avp(SrcT38) || $avp(DstT38))
                            $var(transcoding) = 1; #/* Reset it to transcoding, if codec match set to 0 above */
                        if($avp(SrcSRTP) != SRTP_DISABLE && $avp(rSrcSRTPParam)) {
                            $var(transcoding) = 1; #/* Reset it to transcoding, if codec match set to 0 above */
                            $var(jCrypto)   := '{
                                        "AES_CM_128_HMAC_SHA1_80":  { "crypto": "aes_cm", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "80" },
                                        "AES_CM_128_HMAC_SHA1_32":  { "crypto": "aes_cm", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "32" }, 
                                        "F8_128_HMAC_SHA1_80":      { "crypto": "aes_f8", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "80" }
                            }';
                            $json(jCrypto) := $var(jCrypto) ;
                            $var(true) = 1 ;
                            $var(suite) = null ;
                            for ($var(crypto) in $(avp(rSrcSRTPParam)[*])) {
                                if($var(true)) {
                                    $var(suite) = $(var(crypto){s.select,0,:});
                                    if($json(jCrypto/$var(suite))) { #Supported suite
                                        $var(rsrcmkey) = $(var(crypto){s.select,1,:});
                                        $var(rsrcmsalt) = $(var(crypto){s.select,2,:});
                                        $var(true) = null ;
                                    }
                                }
                            }
                            if($avp(rDstSRTPParam)) {
                                $var(srcmkey) = $(avp(rDstSRTPParam){s.select,1,:});
                                $var(srcmsalt) = $(avp(rDstSRTPParam){s.select,2,:});
                            } else {
                                if(($var(rsrcmkey) && $var(rsrcmsalt))) {
                                    $var(srcrhexenc) = $(RANDOM{s.encode.hexa}) +  $(RANDOM{s.encode.hexa}) +  $(RANDOM{s.encode.hexa}) +  $(RANDOM{s.encode.hexa});
                                    $var(srcmkey) = $(var(srcrhexenc){s.substr,0,32});
                                    $var(srcmsalt) = $(var(srcrhexenc){s.substr,32,28});
                                    $var(srcmkeysalt) = $var(srcmkey) + $var(srcmsalt) ;
                                    $var(srcmkshexdec) = $(var(srcmkeysalt){s.decode.hexa}) ;
                                    $var(srcinline) = $(var(srcmkshexdec){s.encode.base64}) ;
                                    xdbg("$var(srcrhexenc) ==> $var(srcmkey) <<>> $var(srcmsalt) <== $var(srcmkshexdec) <== $var(srcinline) \n");    
                                    $avp(SrcSRTPParam) = $var(suite) + ":" + $var(srcmkey) + ":" + $var(srcmsalt) ;
                                } else {
                                    $avp(rSrcSRTPParam) = null ;
                                    strip_body(); #/* Exit here */
                                }
                            }
                        }
                        if($avp(rDstSRTPParam)) {
                            $var(transcoding) = 1; #/* Reset it to transcoding, if codec match set to 0 above */
                            $var(jCrypto)   := '{
                                            "AES_CM_128_HMAC_SHA1_80":  { "crypto": "aes_cm", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "80" },
                                            "AES_CM_128_HMAC_SHA1_32":  { "crypto": "aes_cm", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "32" }, 
                                            "F8_128_HMAC_SHA1_80":      { "crypto": "aes_f8", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "80" }
                            }';
                            $json(jCrypto) := $var(jCrypto) ;
                            $var(true) = 1 ;
                            $var(suite) = null ;
                            for ($var(crypto) in $(avp(rDstSRTPParam)[*])) {
                                if($var(true)) {
                                    $var(suite) = $(var(crypto){s.select,0,:});
                                    if($json(jCrypto/$var(suite))) { #Supported suite
                                        $var(rdstmkey) = $(var(crypto){s.select,1,:});
                                        $var(rdstmsalt) = $(var(crypto){s.select,2,:});
                                        $var(true) = null ;
                                    }
                                }
                            }
                            $var(true) = 1 ;
                            for ($var(crypto) in $(avp(DstSRTPParam)[*])) {
                                if($var(true)) {
                                    $var(dstsuite) = $(var(crypto){s.select,0,:});
                                    if($var(dstsuite) == $var(suite)) {
                                        $var(dstmkey)  = $(var(crypto){s.select,1,:});
                                        $var(dstmsalt) = $(var(crypto){s.select,2,:});
                                        $var(true) = null;
                                    }
                                }
                            }
                        }
                    }
                    $var(mport) = $(avp(audiomline){s.select,1, });
                    $var(mtype) = $(avp(audiomline){s.select,2, });
                    $var(t38) = $(avp(audiomline){s.select,3, });
                }
    
                xdbg("+++++++++++++++transcoding: $var(transcoding)+++++$var(mport):$var(mtype):$var(t38)+++++\n");
                # DO PASSTHROUGH USING TRANSCODING HARDWARE
                rtpproxy_unforce("$avp(MediaProfileID)");

                $avp(resource) = "resource" + "-" + $ft; /* Grab media port offset from resource-$ft */
                route(DELETE_ALLOMTS_RESOURCE); #Delete previous session, if any

                #remote rtp_nostrict=true in real system
                #no strict used in REST rtp_nostrict=true due to lan/wan emulation with single nic card 
                xdbg("------------------ $avp(rSrcMediaIP):$avp(rSrcMediaPort):$(avp(rSrcCodec)[0])-------- :$avp(SrcMediaPort):$avp(DstMediaPort):\n");
                if($var(transcoding) == 0) { #/* No Transcoding required, PASSTHROUGH */
                    $var(url) =  "gMTSSRV" + "/makepassthrough?remote_ipA=" + $avp(rSrcMediaIP) + "&remote_portA=" + $avp(rSrcMediaPort) + "&remote_ipB=" + $var(csource) + "&remote_portB=" + $var(mport) + "&local_portA=" + $avp(SrcMediaPort) + "&local_portB=" + $avp(DstMediaPort) ;
                } else {
                    if($avp(SrcT38)) {
                        $var(local_rtp_port) = ($(avp(SrcMediaPort){s.int}) - 3); #Dummy port needed by DSP
                        $var(remote_rtp_port) = ($(avp(rSrcMediaPort){s.int}) - 3); #Dummy port needed by DSP 
                        xdbg("------------------ $avp(rSrcT38Param) ------------\n");
                        $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rSrcMediaIP) + "&codec=t38&local_t38_port=" + $avp(SrcMediaPort) + "&remote_t38_port=" + $avp(rSrcMediaPort) + "&local_rtp_port=" + $var(local_rtp_port) + "&remote_rtp_port=" + $var(remote_rtp_port) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_t38=yes" + "&t38_profile=1" ;
                    } else if($avp(SrcSRTP) != SRTP_DISABLE &&  $avp(rSrcSRTPParam)) {
                        $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rSrcMediaIP) + "&codec=" + $(avp(rSrcCodec)[0]) + "&local_rtp_port=" + $avp(SrcMediaPort) + "&remote_rtp_port=" + $avp(rSrcMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_srtp=true&srtp_s_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_s_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_s_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_s_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_s_mst_key=" + $var(srcmkey) + "&srtp_s_mst_salt=" + $var(srcmsalt) + "&srtp_r_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_r_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_r_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_r_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_r_mst_key=" + $var(rsrcmkey) + "&srtp_r_mst_salt=" + $var(rsrcmsalt);
                    } else {
                        $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rSrcMediaIP) + "&codec=" + $(avp(rSrcCodec)[0]) + "&local_rtp_port=" + $avp(SrcMediaPort) + "&remote_rtp_port=" + $avp(rSrcMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true" ;
                    }
                }
                xdbg("Connecting $var(url)\n");
                rest_get("$var(url)","$var(body)");
                $avp($avp(resource)) = $var(body);
                $json(resource1) := $var(body) ;
                if($json(resource1/VT-Index) != null) {
                    $var(idx1) = $json(resource1/VT-Index) ;
                } else if($json(resource1/CPP-Index) != null) {
                    $var(idx1) = $json(resource1/CPP-Index) ;
                }
                avp_db_store("$hdr(call-id)","$avp($avp(resource))");
                xdbg("Got Response $avp(resource) -> $avp($avp(resource)): $(avp(rSrcCodec)[0]):$avp(rSrcMediaPort)<==>$avp(SrcMediaPort)\n");

                $avp(resource) = "resource" + "-" + $tt ;
                route(DELETE_ALLOMTS_RESOURCE); #Delete previous session, if any

                if($var(transcoding) == 0) {
                    $var(url) =  "gMTSSRV" + "/makepassthrough?remote_ipA=" + $var(csource) + "&remote_portA=" + $var(mport) + "&remote_ipB=" + $avp(rSrcMediaIP) + "&remote_portB=" + $avp(rSrcMediaPort) +  "&local_portA=" + $avp(DstMediaPort) + "&local_portB=" + $avp(SrcMediaPort) ;;
                } else {
                    $avp(rDstMediaIP) = $var(csource) ;
                    $avp(rDstMediaPort) =  $var(mport);
                    $avp(rDstCodec) = null ;
                    avp_insert("$avp(rDstCodec)","$var(codec)","10");
                    if($var(DstT38)) {
                        $var(local_rtp_port) = ($(avp(DstMediaPort){s.int}) - 3); #Dummy port needed by DSP
                        $var(remote_rtp_port) = ($(avp(rDstMediaPort){s.int}) - 3); #Dummy port needed by DSP 
                        $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(csource) + "&codec=t38&local_t38_port=" + $avp(DstMediaPort) + "&remote_t38_port=" + $avp(rDstMediaPort) + "&local_rtp_port=" + $var(local_rtp_port) + "&remote_rtp_port=" + $var(remote_rtp_port) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_t38=yes" + "&T38FaxVersion=" + $(avp(rDstT38Param){param.value,T38FaxVersion}) + "&T38MaxBitRate=" +  $(avp(rDstT38Param){param.value,T38MaxBitRate}) + "&T38FaxRateManagement=" + $(avp(rDstT38Param){param.value,T38FaxRateManagement}) + "&T38FaxMaxDatagram=" + $(avp(rDstT38Param){param.value,T38FaxMaxDatagram}) + "&T38FaxUdpEC=" + $(avp(rDstT38Param){param.value,T38FaxUdpEC}) ;
                    } else if($avp(rDstSRTPParam)) {
                        $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rDstMediaIP) + "&codec=" + $(avp(rDstCodec)[0]) + "&local_rtp_port=" + $avp(DstMediaPort) + "&remote_rtp_port=" + $avp(rDstMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_srtp=true&srtp_s_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_s_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_s_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_s_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_s_mst_key=" + $var(dstmkey) + "&srtp_s_mst_salt=" + $var(dstmsalt) + "&srtp_r_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_r_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_r_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_r_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_r_mst_key=" + $var(rdstmkey) + "&srtp_r_mst_salt=" + $var(rdstmsalt);
                    } else {
                        $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $var(csource) + "&codec=" + $var(codec) + "&remote_rtp_port=" + $var(mport) + "&rcname=sbc@allo.com&local_rtp_port=" + $avp(DstMediaPort) + "&rtp_nostrict=true";
                    }
                }
                xdbg("Connecting $var(url)\n");
                rest_get("$var(url)","$var(body)");
                $avp($avp(resource)) = $var(body);
                $json(resource2) := $var(body) ;
                if($json(resource2/VT-Index) != null) {
                            $var(idx2) = $json(resource2/VT-Index) ;
                } else if($json(resource2/CPP-Index) != null) {
                            $var(idx2) = $json(resource2/CPP-Index) ;
                }

                xdbg("Got Index ---->> $var(idx1) <==> $var(idx2) <<  $json(resource2) >> $json(resource2/CPP-Index)\n");
                avp_db_store("$hdr(call-id)","$avp($avp(resource))");
                xdbg("Got Response $avp(resource) -> $avp($avp(resource)): $var(csource):$avp(mport)<==>$avp(DstMediaPort)\n");

                $var(jCodec)   := '{
                            "g729":   { "id": "18", "codec": "g729",  "rtpmap": "a=rtpmap:18 G729/8000", "ptime": 20, "maxptime": 60 },
                            "g711u":  { "id": "0",  "codec": "g711u", "rtpmap": "a=rtpmap:0 PCMU/8000", "ptime": 20, "maxptime": 60 },
                            "g711a":  { "id": "8",  "codec": "g711a", "rtpmap": "a=rtpmap:8 PCMA/8000", "ptime": 20, "maxptime": 60 }
                }';
                $json(jCodec)   := $var(jCodec);

                if($avp(rSrcCodec)) {
                    $var(rSrcCodecid) = $avp($(avp(rSrcCodec)[0])) ;
                    if($avp($var(rSrcCodecid))) {
                        $var(rScodec)  = $avp($var(rSrcCodecid)) ;
                        $json(rjCodec) := $json(jCodec/$var(rScodec)) ;
                        $var(rSrcRtpmap) = $json(rjCodec/rtpmap) ;
                    }
                }

                $var(SDPID1) = $(var(oline){s.select,1, });
                $var(SDPID2) = $(var(oline){s.select,2, });
                xdbg(">>>>>>>>>------------------$var(oline)-->>>> $var(SDPID1) <<>> $var(SDPID2) ---------------------\n");
                $var(sdp) = "v=0\r\n" ;
                $var(sdp) = $var(sdp) + "o=- " + $var(SDPID1) + " " + $var(SDPID2) + " IN IP4 " + $avp(SrcMediaIP) + "\r\n";
                $var(sdp) = $var(sdp) + $(rb{sdp.line,s}) + "\r\n" ;
                $var(sdp) = $var(sdp) + "c=IN IP4 " + $avp(SrcMediaIP) + "\r\n";
                $var(sdp) = $var(sdp) + $(rb{sdp.line,t}) + "\r\n" ;

                if($avp(SrcT38) && $avp(DstT38)) {
                    $var(sdp) = $var(sdp) + "m=image " + $avp(SrcMediaPort) + " udptl t38\r\n" ;
                    $var(i) = 0;
                    $var(t38attr) = $(avp(rDstT38Param){s.select,$var(i),;}) ;
                    while($var(t38attr)) {
                        $var(sdp) = $var(sdp) + "a=" + $var(t38attr) + "\r\n" ;
                        $var(i) = $var(i) + 1;
                        $var(t38attr) = $(avp(rDstT38Param){s.select,$var(i),;}) ;
                    }
                } else {
                    if($avp(SrcT38)) {
            $var(mtype) = null ;
                        $avp(T38Param:1) = "MEDIA:" + $avp(MediaProfileID) ;
                        if(cache_fetch("local","$avp(T38Param:1)",$avp(T38Param:1))) {
                            xdbg("Loaded from cache $avp(T38Param:1): $avp(T38Param:1)\n");
                        } else if (avp_db_load("$avp(T38Param:1)","$avp(T38Param:1)/blox_config")) {
                            cache_store("local","$avp(T38Param:1)","$avp(T38Param:1)");
                            xdbg("Stored in cache $avp(T38Param:1): $avp(T38Param:1)\n");
                        }

                        $avp(SrcT38Param) = $avp(T38Param:1) ;
                        xdbg("------------------SrcT38Param: $avp(SrcT38Param)-----------------------\n");

                        $var(sdp) = $var(sdp) + "m=image " + $avp(SrcMediaPort) + " udptl t38\r\n" ;
                        $var(i) = 0;
                        $var(t38attr) = $(avp(SrcT38Param){s.select,$var(i),;}) ;
                        while($var(t38attr)) {
                            $var(sdp) = $var(sdp) + "a=" + $var(t38attr) + "\r\n" ;
                            $var(i) = $var(i) + 1;
                            $var(t38attr) = $(avp(SrcT38Param){s.select,$var(i),;}) ;
                        }
                        #Adding support for g711 termination for fax passthrough, if T38 not supported
                        #$var(sdp) = $var(sdp) + "m=audio " + $avp(SrcMediaPort) + " RTP/AVP " + "0 8\r\n" ;
                        xdbg("---------+++++++++++Adding T38 in 200 ok reply"); 
                    } else if($avp(rSrcSRTPParam) && $avp(rDstSRTPParam)) {
                        if($avp(SrcSRTP) == SRTP_OPTIONAL || $avp(SrcSRTP) == SRTP_COMPULSORY) {
                            $var(jCrypto)   := '{
                                        "AES_CM_128_HMAC_SHA1_80":  { "crypto": "aes_cm", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "80" },
                                        "AES_CM_128_HMAC_SHA1_32":  { "crypto": "aes_cm", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "32" }, 
                                        "F8_128_HMAC_SHA1_80":      { "crypto": "aes_f8", "auth": "hmac_sha1", "mst_ksize": "128", "auth_size": "80" }
                            }';
                            $json(jCrypto) := $var(jCrypto) ;
                            $var(true) = 1;
                            for ($var(crypto) in $(avp(rDstSRTPParam)[*])) {
                                if($var(true)) {
                                    $var(suite) = $(var(crypto){s.select,0,:});
                                    if($json(jCrypto/$var(suite))) { #Supported suite
                                        $var(rdstinline) = $(var(crypto){s.select,3,:});
                                        $var(true) = null ;
                                    }
                                }
                            }

                            $var(mtype) = " RTP/SAVP " ;
                            $var(cryptoline) = "a=crypto:1 " + $var(suite) + " inline:" + $var(rdstinline) + "\r\n" ;
                        } else {
                            #/* Handled in Route with 488, Error Can't come here*/
                        }
                    } else if($avp(rSrcSRTPParam)) {
                        if($avp(SrcSRTP) != SRTP_DISABLE) {
                            $var(mtype) = " RTP/SAVP ";
                            $var(cryptoline) = "a=crypto:1 " + $var(suite) + " inline:" + $var(srcinline) + "\r\n" ;
                        } else {
                            $var(mtype) = " RTP/AVP ";
                        }
                    } else {
                        $var(mtype) = " RTP/AVP ";
                    }
                    if($var(mtype)) {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(SrcMediaPort) + $var(mtype) + $var(rSrcCodecid) + " 101\r\n" ;
                    }
                    if($var(cryptoline)) {
                        $var(sdp) = $var(sdp) + $var(cryptoline) ;
                    }
                    if($var(mtype)) {
                        $var(sdp) = $var(sdp) + $var(rSrcRtpmap) + "\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-16\r\na=ptime:20\r\na=sendrecv\r\n";
                    }
                }

                xdbg("Got Index ---->> $var(idx1) <==> $var(idx2) <<  $avp(SrcMediaIP) : $avp(SrcMediaPort)\n" ) ;
                #transcoding failed for any reason no need to update the sdp
                if($var(idx1) >= 0 && $var(idx2) >= 0) {
                    add_body("$var(sdp)","application/sdp");
                    set_dlg_flag("DLG_FLAG_TRANSCODING") ; #81 Dialog Transcoding flag
                }

                if($json(resource1/VT-Index) != null && $json(resource2/VT-Index) != null) { #Connect Needed for only voice termnation
                    route(CONNECT_ALLOMTS_RESOURCE);
                }
            } else {
                rtpproxy_answer("of","$avp(SrcMediaIP)","$avp(MediaProfileID)");
                xlog("L_WARN", "+++++++++++++++transcoding: feature disabled for this profile++++++++++\n");
            }
        };
        # Is this a transaction behind a NAT and we did not
        # know at time of request processing?
    } 

    if (nat_uac_test("1")) {
        fix_nated_contact();
    };
}

failure_route[LAN2WAN] {
    if(is_method("INVITE")) {
        if (status =~ "488") {
                xlog("L_WARN", "Not handled, Dropping Call\n");
        }
    }
    if (t_was_cancelled()) {
        rtpproxy_unforce("$avp(MediaProfileID)");
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
    xlog("Failed $rs\n");
}
