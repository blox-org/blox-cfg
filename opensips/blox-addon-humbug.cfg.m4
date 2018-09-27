#Detecting fraud calls
route[HUMBUG_FRAUD_DETECTION] {
    $var(url) = URL;
    $var(body) = "gateway="+API_KEY+"&number="+$fU;
    if(!rest_post("$var(url)","$var(body)", "application/x-www-form-urlencoded", "$var(out)","$var(ct)","$var(rcode)")) {
	xlog("L_ERR","BLOX_DBG: HUMBUG Server Not reachable $var(rcode)!\n");
    } else {
        xdbg("BLOX_DBG::: $var(url) : $var(body) : $var(rcode) : $var(ct) $var(out) $fU $avp(PBX)\n");
        $json(hbRes) := $var(out) ;
        if($json(hbRes/blacklisted) == "true")
        {
            xlog("L_INFO","BLOX_DBG: HUMBUG Dropping request $ru from $fU Fraud call $var(out)\n");
            drop();
            exit;
        }
    }
}
#dnl vim: set ts=4 sw=4 tw=0 et :
