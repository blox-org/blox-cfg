--
-- Table structure for table `blox_subscribe`
--

DROP TABLE IF EXISTS `blox_subscribe`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blox_subscribe` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `from_uri` char(255) NOT NULL DEFAULT '',
  `to_uri` char(255) NOT NULL DEFAULT '',
  `event` char(64) NOT NULL DEFAULT '',
  `socket` char(64) NOT NULL DEFAULT '',
  `extra_hdr` char(255) NOT NULL DEFAULT '',
  `expiry` int(11) NOT NULL DEFAULT '0',
  `last_modified` datetime NOT NULL DEFAULT '1900-01-01 00:00:01',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=41 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

