route[ENUM] {
    $var(ENUMTYPE) = $param(1) ;
    $var(ENUMSX) = $param(2);
    $var(ENUMSE) = $param(3);

    if($var(ENUMSE)==""){$var(ENUMSE)=null;}
    if($var(ENUMSX)==""){$var(ENUMSX)=null;}

    if($var(ENUMSE) && $var(ENUMSX)) {
        if($var(ENUMTYPE) == "ISN") {
            isn_query("$var(ENUMSX)","$var(ENUMSE)") ;
        } else {
            enum_query("$var(ENUMSX)","$var(ENUMSE)") ;
        }
    }
}
