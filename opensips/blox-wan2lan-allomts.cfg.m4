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


#Used for WAN Profiles
route[MTS_WAN2LAN] {
    if($dlg_val(MediaProfileID)) {
        $avp(MediaProfileID) = $dlg_val(MediaProfileID);
    }

    if (has_body("application/sdp")) {
        if(!cache_fetch("local","allomtscodec",$var(codec))) {
            route(ALLOMTSLOAD);
            if(!cache_fetch("local","allomtscodec",$var(codec))) {
                    xlog("L_ERR","BLOX_DBG::: blox-wan2lan-allomts.cfg: Fatal: No allomts codec configured\n");
                    drop(); # /* Drop request only route */
                    exit ;
            }
        }
        $json(jCodec) := $var(codec) ;
        xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------ $json(jCodec)-----------------------\n");

        if(cache_fetch("local","$avp(MediaProfileID)",$avp(MediaProfile))) {
            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Loaded from cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else if (avp_db_load("$avp(MediaProfileID)","$avp(MediaProfile)/blox_profile_config")) {
            cache_store("local","$avp(MediaProfileID)","$avp(MediaProfile)");
            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Stored in cache $avp(MediaProfileID): $avp(MediaProfile)\n");
        } else {
            xlog("L_ERR", "BLOX_DBG::: blox-wan2lan-allomts.cfg: No profile configured for $avp(MediaProfileID): $avp(MediaProfile)\n");
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

        if(is_dlg_flag_set("DLG_FLAG_WAN2LAN")) { #Org Call Intiated from WAN2LAN
            if($DLG_dir == "downstream") { /* Set aprop. LAN WAN Media IP */
                $avp(DstMediaIP) = $avp(MediaLANIP) ;
                $avp(SrcMediaIP) = $avp(MediaWANIP) ;
            } else {
                $avp(DstMediaIP) = $avp(MediaWANIP) ;
                $avp(SrcMediaIP) = $avp(MediaLANIP) ;
            }
        } else { #Should be Re-Invite from WAN2LAN
            if($DLG_dir == "downstream") { /* Set aprop. LAN WAN Media IP */
                $avp(DstMediaIP) = $avp(MediaWANIP) ;
                $avp(SrcMediaIP) = $avp(MediaLANIP) ;
            } else {
                $avp(DstMediaIP) = $avp(MediaLANIP) ;
                $avp(SrcMediaIP) = $avp(MediaWANIP) ;
            }
        }

        if($avp(MediaTranscoding) == "1") {
            $avp(AUDIOCodec) = "MEDIA:" + $avp(MediaProfileID) ;
            if(cache_fetch("local","$avp(AUDIOCodec)",$avp(AUDIOCodec))) {
                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Loaded from cache $avp(AUDIOCodec): $avp(AUDIOCodec)\n");
            } else if (avp_db_load("$avp(AUDIOCodec)","$avp(AUDIOCodec)/blox_config")) {
                cache_store("local","$avp(AUDIOCodec)","$avp(AUDIOCodec)");
                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Stored in cache $avp(AUDIOCodec): $avp(AUDIOCodec)\n");
            }

            $var(oline) = $(rb{sdp.line,o});
            $var(cline) = $(rb{sdp.line,c});

            $var(mt38)   = null ;
            $var(maudio) = null ;
            $var(mvideo) = null ;

            $var(sdpidx) = 0 ;
            $var(mline) = $(rb{sdp.line,m,$var(sdpidx)});
            while($var(mline) != null && $var(mline) != "" && $var(sdpidx) < 3) { #COMMENT: Max 3 Media line will be processed 
                if(($avp(SrcSRTP) == SRTP_DISABLE) && ($(var(mline){s.select,2, }) == "RTP/SAVP")) {
                    xdbg("BLOX_DBG:: blox-wan2lan-allomts.cfg: Ingoring mline $var(mline) SRTP Disabled\n");
                } else {
                    $var(media) = $(var(mline){s.select,0, });
                    $var(media) = $(var(media){s.select,1,=});
                    $var(mport) = $(var(mline){s.select,1, });
                    $var(mtype) = $(var(mline){s.select,2, });
                    $var(t38) = $(var(mline){s.select,3, });

                    xdbg("BLOX_DBG::: Processing :$var(mport):$var(media):$var(t38): $var(mt38):$var(mvideo):$var(audio)\n");
    
                    if($var(mtype) == "udptl" && $var(t38) == "t38" && $var(mt38) == null) {
                        $avp(SrcUdptl) = 1;
                        $avp(SrcT38) = 1;
                        $var(mt38) = 1;
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
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------ $var(rSrcT38Param) ------------\n");
                            $var(i) = $var(i) + 1;
                            $var(aline) = $(rb{sdp.line,a,$var(i)});
                        }
                        $avp(rSrcT38Param) = $(avp(rSrcT38Param){re.subst,/:/=/g}) ;
                        $avp(rSrcT38MediaPort) = $var(mport);
                    } else if($var(media) == "video" && $var(mvideo) == null) {
                        $var(mvideo) = 1;
                        xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: Ignoring media: $var(mline) video not supported\n") ;
                    } else if($var(media) == "audio" && $var(maudio) == null) { #/* Parse SRTP Param*/
                        $avp(srcaudiomline) = $var(mline) ;
                        $var(maudio) = 1 ;
                        $avp(rSrcSRTPParam) = null ;
                        $avp(rSrcSRTPSDP) = null ;
                        $avp(DstSRTPParam) = null ;
                        $var(i) = 0;
                        $var(aline) = $(rb{sdp.line,a,$var(i)});
                        while($var(aline)) {
                            $var(aline) = $(var(aline){s.substr,2,0}) ;
                            $var(crypto) = $(var(aline){s.select,0,:}) ;
                            if(($avp(SrcSRTP) != SRTP_DISABLE) && ($var(crypto) == "crypto")) {
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
                                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: --$json(rSrcSRTPParam)---\n");
                            }
                            $var(i) = $var(i) + 1;
                            $var(aline) = $(rb{sdp.line,a,$var(i)});
                        }
                        $avp(rSrcMediaPort) = $var(mport);
                    } else {
                        xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: Ignoring media: $var(mline) unknown not supported\n") ;
                    }
    
                    if($var(maudio) == null && $var(mt38) == null) {
                        xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: NOT ACCEPTABL HERE Support Fax or Audio\n");
                        sl_send_reply("488","Not Acceptable Here");
                        exit;
                    }
                }

                $var(sdpidx) = $var(sdpidx) + 1 ;
                $var(mline) = $(rb{sdp.line,m,$var(sdpidx)});
            }
            
            if($var(mt38) && $avp(rSrcSRTPParam)) { #T38 with SRTP not supported
                xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: NOT ACCEPTABL HERE $avp(rSrcSRTPParam) <===> $avp(SrcMavp)\n");
                sl_send_reply("488","Not Acceptable Here");
                exit;
            }

            #SRTP Disabled mtype should have RTP/AVP and RTP/SAVP not processed above
            if(($avp(SrcSRTP) == SRTP_DISABLE) && ($var(mtype) != "RTP/AVP")) { 
                xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: NOT ACCEPTABL HERE $avp(rSrcSRTPParam) <===> $avp(SrcMavp)\n");
                sl_send_reply("488","Not Acceptable Here");
                exit;
            }
        
            #If SRTP_COMPULSORY there should be atleast one rSrcSRTPParam
            if($avp(SrcSRTP) == SRTP_COMPULSORY && (!$avp(rSrcSRTPParam))) {
                xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: NOT ACCEPTABL HERE $avp(rSrcSRTPParam) <===> $avp(SrcMavp) <===> $avp(DstSRTP)\n");
                sl_send_reply("488","Not Acceptable Here");
                exit;
            }


            #Supported Codec
            $avp(18) = "g729";
            $avp(0) = "g711u";
            $avp(8) = "g711a";
            $avp(9) = "g722_64";
            $avp(98) = "ilbc_152";
            #$avp(102) = "g722_1_32";
            $avp(4) = "g723";

            $avp(PL_G726_32) = "g726_32";
            $avp(PL_G726_16) = "g726_16";
            $avp(PL_G726_24) = "g726_24";
            $avp(PL_G726_40) = "g726_40";

            $var(i) = 3;
            $var(j) = 0;
            $var(mcodec) = $(avp(srcaudiomline){s.select,$var(i), });

            $avp(rSrcCodec) = null;
            $json(jCodecList) := "{}" ; #jCodecList used for hash manipulation to avoid codec duplication added to rSrcCodec[]
            while($var(mcodec)) {
                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------$var(mcodec)-----------------------\n");
                if($avp($var(mcodec))) {
                    $var(codec) = $avp($var(mcodec)) ;
                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Adding >>>>>>------------------$var(codec)-----------------------\n");
                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Got codec $var(mcodec) $var(codec)\n");
                    avp_insert("$avp(rSrcCodec)","$var(codec)","100");
                    $json(jCodecList/$var(codec)) = $json(jCodec/$var(codec)) ;
                }
                $var(i) = $var(i) + 1;
                $var(mcodec) = $(avp(srcaudiomline){s.select,$var(i), });
            }
            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Remote Src codec list $(avp(rSrcCodec)[0]) $(avp(rSrcCodec)[1])\n");

            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------$json(jCodecList)-----------------------\n");

            $var(i) = 0;
            $var(mcodec) = $(avp(AUDIOCodec){s.select,$var(i),;});
            $var(mcodec) = $(var(mcodec){s.select,0,:}) ;
            $avp(rSrcTransCodec) = null;
            while($var(mcodec)) {
                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------$var(mcodec)-----------------------\n");
                if($avp($var(mcodec))) {
                    $var(codec) = $(avp($var(mcodec)){s.select,0,:}) ;
                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Got codec $var(mcodec) $var(codec)\n");
                    if($json(jCodecList/$var(codec)) == null) {
                        xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Adding >>>>>>------------------$var(codec)-----------------------\n");
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

            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------$var(rtpmaps):$var(codecids)-----------------------\n");

            #Lets reserve the get Media port and reserve it
            $avp(uid) = $hdr(call-id);
            if($ft && $tt) {
                $var(uid) = $avp(uid)+"-"+$ft+"-"+$tt;
            } else {
                $var(uid) = $avp(uid);
            }

            $var(url) =  "gMTSSRV" + "/reservemediaports?uniqueid="+$var(uid);
            xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Route: transcoding request : $var(url)\n");
            rest_get("$var(url)","$var(body)");
            if($var(body) == null) {
                sl_send_reply("500","Server error");
                exit ;
            }

            $json(res) := $var(body) ;
            $var(newaddr) = $avp(DstMediaIP) + ":" + $json(res/local_rtp_port) ;
            xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Route: transcoding reserverd............. :$var(body):$var(newaddr):\n");

            $var(tDstMediaPort) = $(var(newaddr){s.select,1,:}) ;

            $avp(DstMediaPort) = $(var(tDstMediaPort){s.int}) ;
            if(is_direction("upstream")) { #Direction calculated in route
                xdbg("BLOX_DBG:: blox-wan2lan-allomts.cfg: Route: upstream($DLG_dir)\n");
                $avp(SrcMediaPort) = ($avp(DstMediaPort) - gMediaPortOffset);
            } else {
                xdbg("BLOX_DBG:: blox-wan2lan-allomts.cfg: Route: downstream($DLG_dir)\n");
                $avp(SrcMediaPort) = ($avp(DstMediaPort) + gMediaPortOffset);
            }
            $avp(DstT38MediaPort) = ($avp(DstMediaPort) + gT38MediaPortOffset);
            $avp(SrcT38MediaPort) = ($avp(SrcMediaPort) + gT38MediaPortOffset);

            if($var(nat40)) {
                $avp(rSrcMediaIP) = $si ;
            } else {
                $avp(rSrcMediaIP) = $(var(cline){s.select,2, });
            }

            xdbg("BLOX_DBG:: blox-wan2lan-allomts.cfg: ------------------ $avp(rSrcMediaIP):$avp(rSrcMediaPort):$avp(rSrcCodec) -------- :$avp(SrcMediaPort):$avp(DstMediaPort):\n");

            if($avp(SrcT38)) {
                if(!$avp(T38Param)) {
                    $var(cfgparam) = "cfgparam" ;
                    if(avp_db_load("$hdr(call-id)","$avp($var(cfgparam))")) {
                        $var(param) = $(avp($var(cfgparam))) ;
                        $avp(T38Param) = $(var(param){uri.param,T38Param}) ;
                    } else {
                        xlog("L_ERR", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Loading cfgparam\n");
                    }
                }
                if($(avp(T38Param){s.int}) > 0) {
                    $avp(T38Param:1) = "MEDIA:" + $avp(MediaProfileID) ;
                    if(cache_fetch("local","$avp(T38Param:1)",$avp(T38Param:1))) {
                        xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Loaded from cache $avp(T38Param:1): $avp(T38Param:1)\n");
                    } else if (avp_db_load("$avp(T38Param:1)","$avp(T38Param:1)/blox_config")) {
                        cache_store("local","$avp(T38Param:1)","$avp(T38Param:1)");
                        xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Stored in cache $avp(T38Param:1): $avp(T38Param:1)\n");
                    }

                    $avp(SrcT38Param) = $avp(T38Param:1) ;
                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------SrcT38Param: $avp(SrcT38Param)-----------------------\n");

                    $avp(SrcT38Param) = $avp(SrcT38Param) + ";T38FaxMaxDatagram:1400" ;
                    $var(sdp) = $var(sdp) + "m=image " + $avp(DstT38MediaPort) + " udptl t38\r\n" ;
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
                        } 
                    } else if($avp(DstSRTP) == SRTP_COMPULSORY) {
                        $var(sdp) = $var(sdp) + "m=audio " + $avp(DstMediaPort) + " RTP/SAVP " + $var(codecids) + "101\r\n" ;
                        for ($var(aline) in $(avp(rSrcSRTPSDP)[*])) {
                            $var(sdp) = $var(sdp) + "a=" + $var(aline) + "\r\n";
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
        } else {
            xlog("L_WARN", "BLOX_DBG::: blox-wan2lan-allomts.cfg: shouldn't be here: transcoding: feature disabled for this profilen");
            sl_send_reply("500","Internal Media Error");
            exit ;
        }
    }

    t_on_reply("MTS_WAN2LAN");
    t_on_failure("MTS_WAN2LAN");

    if(has_totag()) { #Within dialog
        if($du != null && $du != "") {
            $ru = $du ;
        }
    }

    if(has_totag()) { #Within dialog
        if($DLG_dir == "downstream" && $dlg_val(dcontact)) {
            $du = $dlg_val(dcontact) ;
        }
        if($DLG_dir == "upstream" && $dlg_val(ucontact)) {
            $du = $dlg_val(ucontact) ;
        }
    }

    if(($Ri == $si)) {
        if($du != null && $du != "") {
            $var(du) = $du ; #orginal
            $var(duuri) = "sip:" + $(var(du){uri.host}) + $(var(du){uri.port}) ;
            $var(did) = $(var(du){uri.param,did}) ;
            if($var(did) == null || $var(did) == "") { 
                $var(did) = "" ;
            } else {
                $var(did) = ";did=" + $var(did) ;
            }

            subst("/Contact: +<sip:(.*)@(.*);did=(.*)>(.*)$/Contact: <$var(duuri)$var(did)>\4/");
        }
    }

    if(has_totag()) { #Within dialog
        if($du != null && $du != "") {
            $ru = $du ;
        }
    }

    xlog("L_INFO", "BLOX_DBG::: blox-lan2wan-allomts.cfg: ROUTING $rm - dir: $DLG_dir: from: $fu src:$si:$sp to ru:$ru : down: $avp(dcontact) up:$avp(ucontact) -> dst: $du \n");

    if (!t_relay()) {
        xlog("L_ERR", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Relay error $mb\n");
        sl_reply_error();
    };

    exit;
}

#Used for WAN PROFILE
onreply_route[MTS_WAN2LAN] {
    xlog("L_INFO","BLOX_DBG::: blox-wan2lan-allomts.cfg: Got Response code:$rs from:$fu ru:$ru src:$si:$sp callid:$ci rcv:$Ri:$Rp\n");
    remove_hf("User-Agent");
    insert_hf("User-Agent: USERAGENT\r\n","CSeq") ;
    if(remove_hf("Server")) { #Removed Server success, then add ours
        insert_hf("Server: USERAGENT\r\n","CSeq") ;
    }

    if (status =~ "(183)|2[0-9][0-9]") {
        if (has_body("application/sdp")) {
            $var(uid) = $avp(uid);

            $avp(rDstSRTPParam) = null ;
            $var(transcoding) = 0 ;
            $var(rSrcCodecIdx) = 0;
            $var(cryptoline) = null ;
            if(!cache_fetch("local","allomtscodec",$var(codec))) {
                route(ALLOMTSLOAD);
                if(!cache_fetch("local","allomtscodec",$var(codec))) {
                    xlog("L_ERR","BLOX_DBG::: blox-wan2lan-allomts.cfg: Fatal: No allomts codec configured\n");
                    exit ;
                }
            }

            $json(jCodec) := $var(codec) ;
            if($avp(MediaTranscoding) == "1") {
                $var(oline) = $(rb{sdp.line,o});
                $var(mline) = $(rb{sdp.line,m});
                $var(cline) = $(rb{sdp.line,c});
                $var(transcoding) = 1 ;

                if(nat_uac_test("40")) {
                    $avp(rDstMediaIP) = $si ;
                } else {
                    $avp(rDstMediaIP) = $(var(cline){s.select,2, });
                }

                $var(mt38)   = null ;
                $var(maudio) = null ;
                $var(mvideo) = null ;
                $var(sdpidx) = 0 ;

                $var(mline) = $(rb{sdp.line,m,$var(sdpidx)});
                while($var(mline) != null && $var(mline) != "" && $var(sdpidx) < 3) { #COMMENT: Max 3 Media line will be processed 
                    $var(media) = $(var(mline){s.select,0, });
                    $var(media) = $(var(media){s.select,1,=});

                    $var(mport) = $(var(mline){s.select,1, });
                    $var(mtype) = $(var(mline){s.select,2, });
                    $var(t38) = $(var(mline){s.select,3, });
                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: +++++++++++++++type ------ $var(mline) ==> : $var(t38):$var(mtype):$var(mport) ++++++++++++++\n");
                    if($var(mtype) == "udptl" && $var(t38) == "t38" && $var(mt38) == null) {
                        $var(mt38) = 1 ;
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
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: $var(aline) <<<<< ------------------ $avp(rDstT38Param) ------------\n");
                            $var(i) = $var(i) + 1;
                            $var(aline) = $(rb{sdp.line,a,$var(i)});
                        }
                        $avp(rDstT38Param) = $(avp(rDstT38Param){re.subst,/:/=/g}) ;
                        $avp(rDstT38MediaPort) = $var(mport);
                    } else if($var(media) == "video" && $var(mvideo) == null) {
                        $var(mvideo) = 1;
                        xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: Ignoring media: $var(mline) video not supported\n") ;
                    } else if($var(media) == "audio" && $var(maudio) == null) { #/* Parse SRTP Param*/
                        $var(maudio) = 1 ;
                        $avp(dstaudiomline) = $var(mline) ;
                        $var(mcodec) = $(var(mline){s.select,3, });
                        $avp(18) = "g729";
                        $avp(0) = "g711u";
                        $avp(8) = "g711a";
                        $avp(9) = "g722_64";
#                       $avp(102) = "g722_1_32";
                        $avp(4) = "g723";

                        $avp(PL_G726_32) = "g726_32";
                        $avp(PL_G726_16) = "g726_16";
                        $avp(PL_G726_24) = "g726_24";
                        $avp(PL_G726_40) = "g726_40";

                        $avp(98) = "ilbc_152";

                        $avp(g729) = 18;
                        $avp(g711u) = 0;
                        $avp(g711a) = 8;
                        $avp(g722_64) = 9;
                        #$avp(g722_1_32) = 102;
                        $avp(g723) = 4;

                        $avp(g726_32) = PL_G726_32;
                        $avp(g726_16) = PL_G726_16;
                        $avp(g726_24) = PL_G726_24;
                        $avp(g726_40) = PL_G726_40;

                        $avp(ilbc_152) = 98;

                        $var(codec) = $avp($var(mcodec)) ;

                        $var(rSrcCodecIdx) = 0;
                        $var(rScodec) = $(avp(rSrcCodec)[$var(rSrcCodecIdx)]) ;
                        xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: +++++audio++++++++++$var(mcodec)>>>$var(codec)++++++++++\n");
                        while($var(rScodec)) {
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: +++++++++++++++$var(codec) <==> $var(rScodec)++++++++++\n");
                            if($var(codec) == $var(rScodec)) {
                                $var(transcoding) = 0;
                                $var(rScodec) = null;
                            } else {
                                $var(rScodec) = null;
 
                                $var(rSrcCodecIdx) = $var(rSrcCodecIdx) + 1; 
                                if($(avp(rSrcCodec)[$var(rSrcCodecIdx)])) {
                                    $var(rScodec) = $(avp(rSrcCodec)[$var(rSrcCodecIdx)]) ;
                                }
                            }
                        }
                        if($var(transcoding) != 0) { /* If No codec matched will take the first received source codec id */
                            $var(rSrcCodecIdx) = 0 ;
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
                                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: --$json(rDstSRTPParam)---\n");
                            }
                            $var(i) = $var(i) + 1;
                            $var(aline) = $(rb{sdp.line,a,$var(i)});
                        }
                        $avp(rDstMediaPort) = $var(mport);
                    } else {
                        xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: Ignoring media: $var(mline) unknown not supported\n") ;
                    }
                    $var(sdpidx) = $var(sdpidx) + 1 ;
                    $var(mline) = $(rb{sdp.line,m,$var(sdpidx)});
                }
                if(($var(mtype) == "RTP/SAVP" && $var(mport) == "0")){
                    xlog("L_WARN","BLOX_DBG::: blox-wan2lan-allomts.cfg: Ignoring mport is 0 for RTP/SAVP $avp(rDstSRTPParam)  $avp(DstSRTP) $avp(SrcSRTP)   $var(mtype) $var(mport) $var(RTP/SAVP)\n") ;
                    #while(avp_delete("$avp(rDstSRTPParam)")) {
                    #}
                    # TODO: Replace the below line($avp(rDstSRTPParam) = "") with while loop. avp_delete will clear the 
                    # rDstSRTPParam array.
                    $avp(rDstSRTPParam) = "";
                    $var(crypto) = null;
                }

                if($var(mt38) == null && $var(maudio) == null) {
                    strip_body(); #/* Exit here */
                }

                if($var(mt38) && $var(rDstSRTPParam)) { #T38 with SRTP not supported
                    strip_body(); #/* Exit here */
                }
    
                xdbg("BLOX_DBG::: blox-wan2lan-allomts.cfg: +++++++++++++++transcoding: $var(transcoding)+++++$avp(rDstT38Param)+++++\n");
                if($avp(SrcT38) && $avp(DstT38)) { #Must compare the param and bitrate as well
                    $var(transcoding) = 0; 
                    $var(mport) = $(avp(t38mline){s.select,1, });
                    $var(mtype) = $(avp(t38mline){s.select,2, });
                    $var(t38) = $(avp(t38mline){s.select,3, });
                } else {
                    if(($var(transcoding) == 0) && $avp(rSrcSRTPParam) && $avp(rDstSRTPParam)) {
                        xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: +++++++++++++++SRTP testing : $var(transcoding)+++++$avp(rDstSRTPParam)+++++\n");
                    } else {
                        if($avp(SrcT38) || $avp(DstT38)) {
                            $var(transcoding) = 1; #/* Reset it to transcoding, if codec match set to 0 above */
                        }
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
                                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: $var(srcrhexenc) ==> $var(srcmkey) <<>> $var(srcmsalt) <== $var(srcmkshexdec) <== $var(srcinline) \n");    
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
                        $var(mport) = $(avp(dstaudiomline){s.select,1, });
                        $var(mtype) = $(avp(dstaudiomline){s.select,2, });
                        $var(t38) = $(avp(dstaudiomline){s.select,3, });
                    }
    
                    xdbg("BLOX_DBG::: blox-wan2lan-allomts.cfg: +++++++++++++++transcoding: $var(transcoding)+++++$var(rDstMediaPort):$var(maudio):+++++\n");

                    $avp(resource) = "resource" + "-" + $ft; /* Grab media port offset from resource-$ft */
                    route(DELETE_ALLOMTS_RESOURCE); #Delete previous session, if any

                    #remote rtp_nostrict=true in real system
                    #no strict used in REST rtp_nostrict=true due to lan/wan emulation with single nic card 
                    xdbg("BLOX_DBG:: blox-wan2lan-allomts.cfg: ------------------ $avp(rSrcMediaIP):$avp(rSrcMediaPort):$(avp(rSrcCodec)[$var(rSrcCodecIdx)])-------- :$avp(SrcMediaPort):$avp(DstMediaPort):\n");
                    if($var(transcoding) == 0) { #/* No Transcoding required, PASSTHROUGH */
                        if($avp(SrcT38)) {
                            $var(url) =  "gMTSSRV" + "/makepassthrough?remote_ipA=" + $avp(rSrcMediaIP) + "&remote_portA=" + $avp(rSrcT38MediaPort) + "&remote_ipB=" + $avp(rDstMediaIP) + "&remote_portB=" + $avp(rDstT38MediaPort) + "&local_portA=" + $avp(SrcT38MediaPort) + "&local_portB=" + $avp(DstT38MediaPort) +"&uniqueid="+$var(uid);
                        } else {
                            $var(url) =  "gMTSSRV" + "/makepassthrough?remote_ipA=" + $avp(rSrcMediaIP) + "&remote_portA=" + $avp(rSrcMediaPort) + "&remote_ipB=" + $avp(rDstMediaIP) + "&remote_portB=" + $avp(rDstMediaPort) + "&local_portA=" + $avp(SrcMediaPort) + "&local_portB=" + $avp(DstMediaPort) +"&uniqueid="+$var(uid);
                        }
                    } else {
                        if($avp(SrcT38)) {
                            if($avp(rSrcMediaPort) == null) {
                                $avp(rSrcMediaPort) = $avp(rSrcT38MediaPort) - gT38MediaPortOffset ;
                            }
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------ $avp(rSrcT38Param) ------------\n");
                            $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rSrcMediaIP) + "&codec=t38&local_t38_port=" + $avp(SrcT38MediaPort) + "&remote_t38_port=" + $avp(rSrcT38MediaPort) + "&local_rtp_port=" + $avp(SrcMediaPort) + "&remote_rtp_port=" + $avp(rSrcMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_t38=yes" + "&t38_profile=1" +"&uniqueid="+$var(uid);
                        } else if($avp(SrcSRTP) != SRTP_DISABLE && $avp(rSrcSRTPParam)) {
                            $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rSrcMediaIP) + "&codec=" + $(avp(rSrcCodec)[$var(rSrcCodecIdx)]) + "&local_rtp_port=" + $avp(SrcMediaPort) + "&remote_rtp_port=" + $avp(rSrcMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_srtp=true&srtp_s_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_s_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_s_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_s_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_s_mst_key=" + $var(srcmkey) + "&srtp_s_mst_salt=" + $var(srcmsalt) + "&srtp_r_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_r_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_r_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_r_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_r_mst_key=" + $var(rsrcmkey) + "&srtp_r_mst_salt=" + $var(rsrcmsalt)+"&uniqueid="+$var(uid);
                        } else {
                            $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rSrcMediaIP) + "&codec=" + $(avp(rSrcCodec)[$var(rSrcCodecIdx)]) + "&local_rtp_port=" + $avp(SrcMediaPort) + "&remote_rtp_port=" + $avp(rSrcMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true" +"&uniqueid="+$var(uid);
                        }
                    }
                    xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Connecting $var(url)\n");
                    rest_get("$var(url)","$var(body)");
                    $avp($avp(resource)) = $var(body);
                    $json(resource1) := $var(body) ;
                    if($json(resource1/VT-Index) != null) {
                        $var(idx1) = $json(resource1/VT-Index) ;
                    } else if($json(resource1/CPP-Index) != null) {
                        $var(idx1) = $json(resource1/CPP-Index) ;
                    }
                    if($var(idx1) >= 0) {
                        avp_db_store("$hdr(call-id)","$avp($avp(resource))");
                    }
                    xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Got Response $avp(resource) -> $avp($avp(resource)): $(avp(rSrcCodec)[$var(rSrcCodecIdx)]):$avp(rSrcMediaPort)<==>$avp(SrcMediaPort)\n");

                    $avp(resource) = "resource" + "-" + $tt ;
                    route(DELETE_ALLOMTS_RESOURCE); #Delete previous session, if any

                    if($var(transcoding) == 0) {
                        if($avp(SrcT38)) {
                            $var(url) =  "gMTSSRV" + "/makepassthrough?remote_ipA=" + $avp(rDstMediaIP) + "&remote_portA=" + $avp(rDstT38MediaPort) + "&remote_ipB=" + $avp(rSrcMediaIP) + "&remote_portB=" + $avp(rSrcT38MediaPort) +  "&local_portA=" + $avp(DstT38MediaPort) + "&local_portB=" + $avp(SrcT38MediaPort) +"&uniqueid="+$var(uid);;
                        } else {
                            $var(url) =  "gMTSSRV" + "/makepassthrough?remote_ipA=" + $avp(rDstMediaIP) + "&remote_portA=" + $avp(rDstMediaPort) + "&remote_ipB=" + $avp(rSrcMediaIP) + "&remote_portB=" + $avp(rSrcMediaPort) +  "&local_portA=" + $avp(DstMediaPort) + "&local_portB=" + $avp(SrcMediaPort) +"&uniqueid="+$var(uid);;
                        }
                    } else {
                        $avp(rDstCodec) = null ;
                        avp_insert("$avp(rDstCodec)","$var(codec)","10");
                        if($var(DstT38)) {
                            if($avp(rDstMediaPort) == null)  {
                                $avp(rDstMediaPort) = $avp(rDstT38MediaPort) - gT38MediaPortOffset ; #Dummy reserved port
                            }
                            $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rDstMediaIP) + "&codec=t38&local_t38_port=" + $avp(DstMediaPort) + "&remote_t38_port=" + $avp(rDstMediaPort) + "&local_rtp_port=" + $avp(DstMediaPort) + "&remote_rtp_port=" + $avp(rDstMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_t38=yes" + "&T38FaxVersion=" + $(avp(rDstT38Param){param.value,T38FaxVersion}) + "&T38MaxBitRate=" +  $(avp(rDstT38Param){param.value,T38MaxBitRate}) + "&T38FaxRateManagement=" + $(avp(rDstT38Param){param.value,T38FaxRateManagement}) + "&T38FaxMaxDatagram=" + $(avp(rDstT38Param){param.value,T38FaxMaxDatagram}) + "&T38FaxUdpEC=" + $(avp(rDstT38Param){param.value,T38FaxUdpEC}) +"&uniqueid="+$var(uid);
                        } else if($avp(rDstSRTPParam)) {
                            $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rDstMediaIP) + "&codec=" + $(avp(rDstCodec)[0]) + "&local_rtp_port=" + $avp(DstMediaPort) + "&remote_rtp_port=" + $avp(rDstMediaPort) + "&rcname=sbc@allo.com&rtp_nostrict=true&enable_srtp=true&srtp_s_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_s_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_s_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_s_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_s_mst_key=" + $var(dstmkey) + "&srtp_s_mst_salt=" + $var(dstmsalt) + "&srtp_r_crypto=" + $json(jCrypto/$var(suite)/crypto) + "&srtp_r_auth=" + $json(jCrypto/$var(suite)/auth) + "&srtp_r_auth_size=" + $json(jCrypto/$var(suite)/auth_size) + "&srtp_r_mst_ksize=" + $json(jCrypto/$var(suite)/mst_ksize) + "&srtp_r_mst_key=" + $var(rdstmkey) + "&srtp_r_mst_salt=" + $var(rdstmsalt) +"&uniqueid="+$var(uid);
                        } else {
                            $var(url) =  "gMTSSRV" + "/create?remote_ip=" + $avp(rDstMediaIP) + "&codec=" + $var(codec) + "&remote_rtp_port=" + $avp(rDstMediaPort) + "&rcname=sbc@allo.com&local_rtp_port=" + $avp(DstMediaPort) + "&rtp_nostrict=true" +"&uniqueid="+$var(uid);
                        }
                    }
                    xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Connecting $var(url)\n");
                    rest_get("$var(url)","$var(body)");
                    $avp($avp(resource)) = $var(body);
                    $json(resource2) := $var(body) ;
                    if($json(resource2/VT-Index) != null) {
                        $var(idx2) = $json(resource2/VT-Index) ;
                    } else if($json(resource2/CPP-Index) != null) {
                        $var(idx2) = $json(resource2/CPP-Index) ;
                    }

                    xdbg("BLOX_DBG::: blox-wan2lan-allomts.cfg: Got Index ---->> $var(idx1) <==> $var(idx2) <<  $json(resource2) >> $json(resource2/CPP-Index)\n");
                    if($var(idx2) >= 0) {
                        avp_db_store("$hdr(call-id)","$avp($avp(resource))");
                    }
                    xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Got Response $avp(resource) -> $avp($avp(resource)): $var(rDstMediaIP):$avp(mport)<==>$avp(DstMediaPort)\n");
                    if($avp(rSrcCodec)) {
                        $var(rSrcCodecid) = $avp($(avp(rSrcCodec)[$var(rSrcCodecIdx)])) ;
                        if($avp($var(rSrcCodecid))) {
                            $var(rScodec)  = $avp($var(rSrcCodecid)) ;
                            $json(rjCodec) := $json(jCodec/$var(rScodec)) ;
                            $var(rSrcRtpmap) = $json(rjCodec/rtpmap) ;
                        }
                    }

                    $var(SDPID1) = $(var(oline){s.select,1, });
                    $var(SDPID2) = $(var(oline){s.select,2, });
                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: >>>>>>>>>------------------$var(oline)-->>>> $var(SDPID1) <<>> $var(SDPID2) ---------------------\n");
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
                                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Loaded from cache $avp(T38Param:1): $avp(T38Param:1)\n");
                            } else if (avp_db_load("$avp(T38Param:1)","$avp(T38Param:1)/blox_config")) {
                                cache_store("local","$avp(T38Param:1)","$avp(T38Param:1)");
                                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Stored in cache $avp(T38Param:1): $avp(T38Param:1)\n");
                            }

                            $avp(SrcT38Param) = $avp(T38Param:1) ;
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ------------------SrcT38Param: $avp(SrcT38Param)-----------------------\n");

                            $avp(SrcT38Param) = $avp(SrcT38Param) + ";T38FaxMaxDatagram:1400" ;
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
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ---------+++++++++++Adding T38 in 200 ok reply"); 
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
                                xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: ---------+++++++++++Adding Both Side SRTP 200 ok reply $var(suite) : $var(rdstinline)"); 
                            } else {
                                #/* Handled in Route with 488, Error Can't come here*/
                                xlog("L_ERR","BLOX_DBG::: blox-wan2lan-allomts.cfg: BROKEN ROUTE\n");
                            }
                        } else if($avp(rSrcSRTPParam)) {
                            xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: SRTP configuration  ---->> $avp(SrcMavp) ==  <==> <<  $avp(MediaEncryption) \n");
  
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

                    xdbg("BLOX_DBG: blox-wan2lan-allomts.cfg: Got Index ---->> $var(idx1) <==> $var(idx2) <<  $avp(SrcMediaIP) : $avp(SrcMediaPort)\n" ) ;
                    #transcoding failed for any reason no need to update the sdp
                    if($var(idx1) >= 0 && $var(idx2) >= 0) {
                        add_body("$var(sdp)","application/sdp");
                        set_dlg_flag("DLG_FLAG_TRANSCODING") ; #81 Dialog Transcoding flag
                    }

                    if($json(resource1/VT-Index) != null && $json(resource2/VT-Index) != null) { #Connect Needed for only voice termnation
                        route(CONNECT_ALLOMTS_RESOURCE);
                    }
                }
            } else {
                xlog("L_WARN", "BLOX_DBG::: blox-wan2lan-allomts.cfg: transcoding: feature disabled for this profile\n");
            }
        };

        if(is_method("INVITE")) {
            if(nat_uac_test("96")) { # /* If Contact not same as source IP Address */
                if(!is_ip_rfc1918("$si")) { # /* Set Source IP, Source is Priviate IP and received!=via */
                    $var(ctparams) = $ct.fields(params) ;
                    xdbg("BLOX_DBG::: blox-wan2lan-allomts.cfg: $DLG_dir | Set Source IP, Source is Priviate IP and received!=via  $si:$sp;$var(ctparams)\n");
                    if($DLG_dir == "downstream") {
                        $dlg_val(ucontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    } else {
                        $dlg_val(dcontact) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    }
                } else { # /* Set 200 OK Contact */
                    $var(cturi) = $ct.fields(uri) ;
                    $var(cthost) = $(var(cturi){uri.host}) ;
                    $dlg_val(rcv) = "sip:" + $si + ":" + $sp + ";transport=" + $proto ;
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: $ct ==> $var(cthost) <==> $Ri : $dlg_val(loop)\n");
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: $DLG_dir | Set Source IP, Source is Priviate IP and received!=via  $si:$sp;$var(ctparams)\n");
                    xdbg("BLOX_DBG::: blox-wan2lan.cfg: Set 200 OK Contact $ct.fields(uri)\n");
                    if($DLG_dir == "downstream") {
                        $dlg_val(ucontact) = $ct.fields(uri) ;
                    } else {
                        $dlg_val(dcontact) = $ct.fields(uri) ;
                    }
                }
                xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: $ct != $si Response to contact different source $DLG_dir -> $dlg_val(ucontact) -> $dlg_val(dcontact) <-\n");
            }
        }
    }

    if (nat_uac_test("3")) {
        fix_nated_contact();
    };
}

failure_route[MTS_WAN2LAN] {
    if(is_method("INVITE")) {
        if (status =~ "488") {
            xlog("L_WARN", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Not handled, Dropping Call\n");
        }
        if($avp(DstMediaPort) != null) {
            $var(uid) = $avp(uid);

            $var(url) =  "gMTSSRV" + "/unreservemediaports?local_rtp_port=" + $avp(DstMediaPort) +"&uniqueid="+$var(uid);
            xlog("L_INFO", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Route: transcoding request : $var(url)\n");
            rest_get("$var(url)","$var(body)");
        }
    }
    if (t_was_cancelled()) {
        $avp(resource) = "resource" + "-" + $ft ;
        route(DELETE_ALLOMTS_RESOURCE);
        exit;
    }
    xlog("L_WARN", "BLOX_DBG::: blox-wan2lan-allomts.cfg: Failed $rs\n");
}
