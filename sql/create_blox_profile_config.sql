--
-- Table structure for table `blox_profile_config`
--

DROP TABLE IF EXISTS `blox_profile_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blox_profile_config` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` char(64) NOT NULL DEFAULT '',
  `attribute` char(32) NOT NULL DEFAULT '',
  `type` int(11) NOT NULL DEFAULT '0',
  `value` char(255) NOT NULL DEFAULT '',
  `last_modified` datetime NOT NULL DEFAULT '1900-01-01 00:00:01',
  PRIMARY KEY (`id`),
  KEY `va_idx` (`uuid`,`attribute`),
  KEY `value_idx` (`value`)
) ENGINE=MyISAM AUTO_INCREMENT=32 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blox_profile_config`
--
