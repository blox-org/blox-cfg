--
-- Table structure for table `blox_config_ext`
--

DROP TABLE IF EXISTS `blox_config_ext`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blox_config_ext` (
  `uuid` char(64) NOT NULL DEFAULT '',
  `LBID` int(11) NOT NULL,
  `LBRuleID` int(11) NOT NULL,
  `SHMP` char(64) NOT NULL DEFAULT ''
) ENGINE=MyISAM AUTO_INCREMENT=35 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
