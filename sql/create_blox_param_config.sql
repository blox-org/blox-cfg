--
-- Table structure for table `blox_param_config`
--

DROP TABLE IF EXISTS `blox_param_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE blox_param_config ( 
 uuid char(64) PRIMARY KEY,
 LAN integer NOT NULL,
 WAN integer NOT NULL,
 MEDIA integer NOT NULL,
 MAXInbound integer NOT NULL,
 MAXOutbound integer NOT NULL,
 GWID integer NOT NULL,
 LANSRTP integer NOT NULL,
 WANSRTP integer NOT NULL,
 T38Param integer NOT NULL,
 DOMAIN char(255) 
) ;
/*!40101 SET character_set_client = @saved_cs_client */;
