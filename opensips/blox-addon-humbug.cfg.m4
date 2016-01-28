#Detecting fraud calls
route[HUMBUG_FRAUD_DETECTION] {
    $var(url) = URL;
    $var(body) = "gateway="+API_KEY+"&number="+$rU;
    rest_post("$var(url)","$var(body)", "application/x-www-form-urlencoded", "$var(out)","$var(ct)","$var(rcode)");
    xlog("L_INFO","$var(url) : $var(body) : $var(rcode) : $var(ct) $var(out) $rU $avp(PBX)\n");
    $var(result)=$(var(out){s.select,1,:});
    xlog("L_INFO","result $var(result)\n");
    if(!($var(result) == "false}"))
    {
        xlog("L_INFO"," Dropping the Fraud call to $ru \n");
        drop();
        exit;
    }

}
