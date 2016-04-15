route[BLOX_DOMAIN] {
    $var(uuid) = "DOM" + $param(1) + ":" + $rd ;
    if (method == "REGISTER") {
        $avp(REGURI) = "";    
        if(cache_fetch("local","$var(uuid)",$avp(REGURI))) {
            xdbg("Loaded from cache $var(uuid): $avp(REGURI)\n");
        } else if (avp_db_load("$var(uuid)","$avp(REGURI)/blox_domain")) {
            cache_store("local","$var(uuid)","$avp(REGURI)");
            xdbg("Stored in cache $var(uuid): $avp(REGURI)\n");
        } else {
            $avp(REGURI) = null;
            xlog("L_WARN", "BLOX_DBG::: REGISTER METHOD Invaid Domain name routing in blox in register attribute $var(uuid)\n" );
        }

        $du = $avp(REGURI) ;
        xlog("BLOX_DBG::: REGISTER METHOD  Domain name routing in blox in register $avp(uuid) $du   $avp(REGURI)  \n" );
        return(1);
    }
    if (method == "SUBSCRIBE") {
        $avp(SUBURI) = "";    
        if(cache_fetch("local","$var(uuid)",$avp(SUBURI))) {
            xdbg("Loaded from cache $var(uuid): $avp(SUBURI)\n");
        } else if (avp_db_load("$var(uuid)","$avp(SUBURI)/blox_domain")) {
            cache_store("local","$var(uuid)","$avp(SUBURI)");
            xdbg("Stored in cache $var(uuid): $avp(SUBURI)\n");
        } else {
            $avp(SUBURI) = null;
            xlog("L_WARN", "BLOX_DBG::: SUBSCRIBE METHOD Invaid Domain name routing  in blox Subscribe $var(uuid)\n" );
        }

        $du = $avp(SUBURI) ;
        return(1);
    }
    if (method == "PUBLISH") {
        $avp(PUBURI) = "";    
        if(cache_fetch("local","$var(uuid)",$avp(PUBURI))) {
            xdbg("Loaded from cache $var(uuid): $avp(PUBURI)\n");
        } else if (avp_db_load("$var(uuid)","$avp(PUBURI)/blox_domain")) {
            cache_store("local","$var(uuid)","$avp(PUBURI)");
            xdbg("Stored in cache $var(uuid): $avp(PUBURI)\n");
        } else {
            $avp(PUBURI) = null;
            xlog("L_WARN", "BLOX_DBG::: PUBLISH METHOD Invaid Domain name routing  in blox Publish $var(uuid)\n" );
        }

        $du = $avp(PUBURI) ;
        return(1);
    }

    $avp(DEFURI) = "";    
    if(cache_fetch("local","$var(uuid)",$avp(DEFURI))) {
        xdbg("Loaded from cache $var(uuid): $avp(DEFURI)\n");
    } else if (avp_db_load("$var(uuid)","$avp(DEFURI)/blox_domain")) {
        cache_store("local","$var(uuid)","$avp(DEFURI)");
        xdbg("Stored in cache $var(uuid): $avp(DEFURI)\n");
    } else {
        $avp(DEFURI) = null;
        xlog("L_WARN", "BLOX_DBG::: INVITE METHOD Invaid Domain name routing  in blox Publish $var(uuid)\n" );
    }

    $du = $avp(DEFURI) ;
    xlog("L_WARN", "BLOX_DBG:::  domain name routing module attribute $var(uuid) $avp(DEFURI) \n");
}
