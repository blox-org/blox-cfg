--
-- Table structure for table `blox_codec`
--

DROP TABLE IF EXISTS `blox_codec`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blox_codec` (
  `codec` TEXT(1024) NOT NULL 
);
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blox_codec`
--
INSERT INTO blox_codec set codec='{"ilbc_152": {"id": "98","codec": "ilbc_152","rtpmap": "a=rtpmap:98 iLBC/8000","ptime": 20,"maxptime": 60},"g722_64": {"id": "9","codec": "g722_64","rtpmap": "a=rtpmap:9 G722/8000","ptime": 20,"maxptime": 60},
    "g723": {"id": "4","codec": "g723","rtpmap": "a=rtpmap:4 G723/8000","ptime": 20,"maxptime": 60},
    "g726_40": {"id": "104","codec": "g726_40","rtpmap": "a=rtpmap:104 G726-40/8000","ptime": 20,"maxptime": 60},
    "g726_32": {"id": "99","codec": "g726_32","rtpmap": "a=rtpmap:99 G726-32/8000","ptime": 20,"maxptime": 60},
    "g726_24": {"id": "102","codec": "g726_24","rtpmap": "a=rtpmap:102 G726-24/8000","ptime": 20,"maxptime": 60},
    "g726_16": {"id": "112","codec": "g726_16","rtpmap": "a=rtpmap:112 G726-16/8000","ptime": 20,"maxptime": 60},
    "g711u": {"id": "0","codec": "g711u","rtpmap": "a=rtpmap:0 PCMU/8000","ptime": 20,"maxptime": 60},
    "g729": {"id": "18","codec": "g729","rtpmap": "a=rtpmap:18 G729/8000","ptime": 20,"maxptime": 60},
    "g711a": {"id": "8","codec": "g711a","rtpmap": "a=rtpmap:8 PCMA/8000","ptime": 20,"maxptime": 60}
}';
