/* vim: set foldmethod=marker: */
#ifndef _IPV4_H_
#define _IPV4_H_

#define IPV4_ADDR_LEN                        4
#define IPV4_MAX_HEADER_LEN                 60
#define IPV4_DEFAULT_HEADER_LEN             20
#define IPV4_PAYLOAD_LEN                   200

/* IPv4 header  {{{
    0               1               2               3
    1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 0 |Version|  IHL  |Type of Service|          Total Length         |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 4 |         Identification        |Flags|      Fragment Offset    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 8 |  Time to Live |    Protocol   |         Header Checksum       |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
12 |                       Source Address                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
16 |                    Destination Address                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
20 |                    Options                    |    Padding    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+*/

#define IPV4_VERSION          0
#define IPV4_IHL              0 /* Internet Header Length in words of 4 bytes */
#define IPV4_TOS              1
#define IPV4_TOTAL_LENGTH     2 /* In bytes */
#define IPV4_IDENTIFICATION   4
#define IPV4_FLAGS            6
#define IPV4_FRAG_OFFSET      6
#define IPV4_TTL              8
#define IPV4_PROTOCOL         9
#define IPV4_H_CHECKSUM      10
#define IPV4_SRC_ADDR        12
#define IPV4_DST_ADDR        16
#define IPV4_OPTIONS         20

#define IPV4_ICMP_TOM         0 /* Type of message */
#define IPV4_ICMP_CODE        1
#define IPV4_ICMP_CHECKSUM    2
#define IPV4_ICMP_HEADER      4
#define IPV4_ICMP_PAYLOAD     8 /* Optional */
/* }}} */
/* https://tools.ietf.org/html/rfc790 {{{ */
// #define INTERNET_PROTOCOL_NUMBER_RESERVED 0
#define INTERNET_PROTOCOL_NUMBER_ICMP                               1
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 2
#define INTERNET_PROTOCOL_NUMBER_GATEWAY_TO_GATEWAY                 3
#define INTERNET_PROTOCOL_NUMBER_CMCC_GATEWAY_MONITORING_MESSAGE    4
#define INTERNET_PROTOCOL_NUMBER_ST                                 5
#define INTERNET_PROTOCOL_NUMBER_TCP                                6
#define INTERNET_PROTOCOL_NUMBER_UCL                                7
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 8
#define INTERNET_PROTOCOL_NUMBER_SECURE                             9
#define INTERNET_PROTOCOL_NUMBER_BBN_RCC_MONITORING                10
#define INTERNET_PROTOCOL_NUMBER_NVP                               11
#define INTERNET_PROTOCOL_NUMBER_PUP                               12
#define INTERNET_PROTOCOL_NUMBER_PLURIBUS                          13
#define INTERNET_PROTOCOL_NUMBER_TELENET                           14
#define INTERNET_PROTOCOL_NUMBER_XNET                              15
#define INTERNET_PROTOCOL_NUMBER_CHAOS                             16
#define INTERNET_PROTOCOL_NUMBER_USER_DATAGRAM                     17
#define INTERNET_PROTOCOL_NUMBER_MULTIPLEXING                      18
#define INTERNET_PROTOCOL_NUMBER_DCN                               19
#define INTERNET_PROTOCOL_NUMBER_TAC_MONITORING                    20
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 21-62
#define INTERNET_PROTOCOL_NUMBER_ANY_LOCAL_NETWORK                 63
#define INTERNET_PROTOCOL_NUMBER_SATNET_AND_BACKROOM_EXPAK         64
#define INTERNET_PROTOCOL_NUMBER_MIT_SUBNET_SUPPORT                65
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 66-68
#define INTERNET_PROTOCOL_NUMBER_SATNET_MONITORING                 69
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 70
#define INTERNET_PROTOCOL_NUMBER_INTERNET_PACKET_CORE_UTILITY      71
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 72-75
#define INTERNET_PROTOCOL_NUMBER_BACKROOM_SATNET_MONITORING        76
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 77
#define INTERNET_PROTOCOL_NUMBER_WIDEBAND_MONITORING               78
#define INTERNET_PROTOCOL_NUMBER_WIDEBAND_EXPAK                    79
// #define INTERNET_PROTOCOL_NUMBER_UNASSIGNED 80-254
// #define INTERNET_PROTOCOL_NUMBER_RESERVED 255
/* }}} */

#endif
