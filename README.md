# What is Session Border Controller(SBC) ? #

A **Session Border Controller(SBC)** is used to control VoIP signaling and media streams. SBC is responsible for setting up, conducting, and tearing down calls. SBC allows owners to control the types of call that can be placed through the networks and also overcome some of the problems caused by firewalls and NAT for VoIP calls. A common location for a stand-alone SBC is a connection point, called a border, between a private local area network (LAN) and the Internet. SBC polices real-time voice traffic between IP network borders ensuring your private network is robustly secure and fully manageable.

SBC is enabled with DPI Packet Inspection on VOIP traffic, supporting the Signatures for Key Malwares/Vulnerabilities observed in SIP Deployments like Extensions Enumeration DoS and Password Cracking. Supporting Open Source PBXs like Asterisk, FreeSwitch, TrixBox.
Handles the SIP-NAT issues observed in the common VOIP deployments.
Topology-hiding function is to prevent customers or other service providers from learning details about how the internal network is configured, or how calls being placed through the SBC are routed.

## Basic Functions ##

- Eliminates bad VoIP signaling and media protocol at the network boundary.
- Built-in firewall which can controls IP Addresses/Port based Filtering, DOS/DDOS Attacks, IP Blacklist & NAT. It opens pinhole in the firewall to allow VoIP signaling and media to pass through.
- Media bridging, which may include Voice over IP and Fax over IP.
- Roaming Extension for Internal SIP PBX.
- Support for SIP Outbound/Inbound Trunk and policies to route the calls.
- DTMF Support for RFC2833/INBAND/SIP INFO
- Can handle simultaneous calls from 10 to 60 channels (Including Media Transcoding and Encryption)
- Easy GUI Configuration and call statistics.

## Advanced Features ##

- Transcoding SBCs can also allow VoIP calls to be set up between two phones by transcoding of the media stream, when different codecs are in use
- TLS/SRTP support for signaling and media encryption
- Policy-based call routing, including crank back of call setup

# Major Modules #

## Basic Version ##
- **Opensips** SIP router, generally used to route SIP messages between two endpoints following RFC 3261 and may SIP related supported RFC. The Opensips script does main SBC features like topology hiding, header manipulation, registration forwarding etc
- **rtpproxy** Media router helps to route media between NATted environment also secures broken media protocol. It is customized to do firewall pinholing (dynamic port opening) using a virtual interface.
- **miniupnpd-nat-pmp-auth** It is customized miniupnpd with authentication to do media pin-holing and port forwarding media to rtpproxy.

## Advanced Version ##

**Media Transcoding Server** is a nginx module to provide RESTful feature of Media Transcoding and other media related service. This module works with 'Allo Transcoding PCI express Card'

Following features are available

* Supported Codecs *G722.2, AMR, GSM-EFR, GSM-FR, G.711, G.722, G.722 1C/Siren 14, G.723.1, G.726, G.729AB, iLBC*
* Secure RTP (*Media encryption*)
* T.38 Fax
* Fax/Video By-Pass
* DTMF deduction & generation / relay.
* Media Pin-holing (*Miniupnp integrated*)
* RTCP Support
* Media statistics
* Echo cancellation
* Call Recording
* Lawful Interception
* Conference Support
