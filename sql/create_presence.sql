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

--
-- Table structure for table `locationpresence`
--

DROP TABLE IF EXISTS `locationpresence`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `locationpresence` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` char(64) NOT NULL DEFAULT '',
  `domain` char(64) NOT NULL DEFAULT '',
  `contact` char(255) NOT NULL DEFAULT '',
  `received` char(128) DEFAULT NULL,
  `path` char(255) DEFAULT NULL,
  `expires` datetime NOT NULL DEFAULT '2020-05-28 21:32:15',
  `q` float(10,2) NOT NULL DEFAULT '1.00',
  `callid` char(255) NOT NULL DEFAULT 'Default-Call-ID',
  `cseq` int(11) NOT NULL DEFAULT '13',
  `last_modified` datetime NOT NULL DEFAULT '1900-01-01 00:00:01',
  `flags` int(11) NOT NULL DEFAULT '0',
  `cflags` char(255) DEFAULT NULL,
  `user_agent` char(255) NOT NULL DEFAULT '',
  `socket` char(64) DEFAULT NULL,
  `methods` int(11) DEFAULT NULL,
  `sip_instance` char(255) DEFAULT NULL,
  `attr` char(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_contact_idx` (`username`,`domain`,`contact`,`callid`)
) ENGINE=MyISAM AUTO_INCREMENT=415 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `blox_presence_subscriber`
--

DROP TABLE IF EXISTS `blox_presence_subscriber`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blox_presence_subscriber` (
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `username` char(64) NOT NULL DEFAULT '',
  `domain` char(64) NOT NULL DEFAULT '',
  `password` char(25) NOT NULL DEFAULT '',
  `email_address` char(64) NOT NULL DEFAULT '',
  `ha1` char(64) NOT NULL DEFAULT '',
  `ha1b` char(64) NOT NULL DEFAULT '',
  `rpid` char(64) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
