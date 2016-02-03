CREATE TABLE `locationtrunk` (
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
) ENGINE=MyISAM AUTO_INCREMENT=62 DEFAULT CHARSET=latin1;

