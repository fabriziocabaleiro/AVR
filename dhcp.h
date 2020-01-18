/* vim: set foldmethod=marker: */
#ifndef _DHCP_H_
#define _DHCP_H_

#include "services.h"

/* During rebooting state, we send a request packet, then we wait up to
 * REBOOTING_WAIT_SECONDS_FOR_ACK seconds for an ACK, or go to the initial state
 */

#define DHCP_TIMER_LAP  7

/* DHCP states {{{1 ----------------------------------------------------------*/
#define DHCP_STATE_INIT         0
#define DHCP_STATE_SELECTING    1
#define DHCP_STATE_REQUESTING   2
#define DHCP_STATE_BOUND        3
#define DHCP_STATE_RENEWING     4
#define DHCP_STATE_REBINDING    5
#define DHCP_STATE_INIT_REBOOT  6
#define DHCP_STATE_REBOOTING    7

/* DHCP Packet sizes {{{1 ----------------------------------------------------*/
#define DHCP_UDP_DST_PORT INTERNET_SERVICE_BOOTPS_67_UDP
#define DHCP_UDP_SRC_PORT INTERNET_SERVICE_BOOTPC_68_UDP

#define DHCP_IP_HEADER_SIZE     20
#define DHCP_UDP_BASE_PKT_SIZE  (     8 + /* UDP header */          \
                                 11 * 4 + /* before BOOTP legacy */ \
                                    192 + /* BOOTP legacy */        \
                                      4 + /* magic cookie */        \
                                      3 + /* DHCP message */        \
                                      1   /* endmark */             \
                                )

#define DHCP_REQUEST_EXTRA_OPS_SIZE (6 + /* Address Request */ \
                                     6 + /* Server IP address */ \
                                     6   /* Hostname */ \
                                    )

#define DHCP_UDP_COMMON_PKT_SIZE      (DHCP_UDP_BASE_PKT_SIZE)
#define DHCP_IP_COMMON_PKT_SIZE       (DHCP_UDP_COMMON_PKT_SIZE + \
                                       DHCP_IP_HEADER_SIZE)

#define DHCP_UDP_REQUEST_PKT_SIZE     (DHCP_UDP_BASE_PKT_SIZE + \
                                       DHCP_REQUEST_EXTRA_OPS_SIZE)
#define DHCP_IP_REQUEST_PKT_SIZE      (DHCP_UDP_REQUEST_PKT_SIZE + \
                                       DHCP_IP_HEADER_SIZE)

/* DHCP header {{{1 ------------------------------------------------------------
 *     0                   1                   2                   3
 *     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *   0 |     op (1)    |   htype (1)   |   hlen (1)    |   hops (1)    |
 *     +---------------+---------------+---------------+---------------+
 *   4 |                            xid (4)                            |
 *     +-------------------------------+-------------------------------+
 *   8 |           secs (2)            |           flags (2)           |
 *     +-------------------------------+-------------------------------+
 *  12 |                          ciaddr  (4)                          |
 *     +---------------------------------------------------------------+
 *  16 |                          yiaddr  (4)                          |
 *     +---------------------------------------------------------------+
 *  20 |                          siaddr  (4)                          |
 *     +---------------------------------------------------------------+
 *  24 |                          giaddr  (4)                          |
 *     +---------------------------------------------------------------+
 *  28 |                          chaddr  (16)                         |
 *     +---------------------------------------------------------------+
 *  44 |                          sname   (64)                         |
 *     +---------------------------------------------------------------+
 * 108 |                          file    (128)                        |
 *     +---------------------------------------------------------------+
 * 236 |                          options (variable)                   |
 *     +---------------------------------------------------------------+
 *
 *    FIELD      OCTETS       DESCRIPTION
 *    -----      ------       -----------
 *
 *    op            1  Message op code / message type.
 *                     1 = BOOTREQUEST, 2 = BOOTREPLY
 *    htype         1  Hardware address type, see ARP section in "Assigned
 *                     Numbers" RFC; e.g., '1' = 10mb ethernet.
 *    hlen          1  Hardware address length (e.g.  '6' for 10mb
 *                     ethernet).
 *    hops          1  Client sets to zero, optionally used by relay agents
 *                     when booting via a relay agent.
 *    xid           4  Transaction ID, a random number chosen by the
 *                     client, used by the client and server to associate
 *                     messages and responses between a client and a
 *                     server.
 *    secs          2  Filled in by client, seconds elapsed since client
 *                     began address acquisition or renewal process.
 *    flags         2  Flags (see figure 2).
 *    ciaddr        4  Client IP address; only filled in if client is in
 *                     BOUND, RENEW or REBINDING state and can respond
 *                     to ARP requests.
 *    yiaddr        4  'your' (client) IP address.
 *    siaddr        4  IP address of next server to use in bootstrap;
 *                     returned in DHCPOFFER, DHCPACK by server.
 *    giaddr        4  Relay agent IP address, used in booting via a
 *                     relay agent.
 *    chaddr       16  Client hardware address.
 *    sname        64  Optional server host name, null terminated string.
 *    file        128  Boot file name, null terminated string; "generic"
 *                     name or null in DHCPDISCOVER, fully qualified
 *                     directory-path name in DHCPOFFER.
 *    options     var  Optional parameters field.  See the options
 *                     documents for a list of defined options.
 */

/* DHCP Header data structure {{{1 -------------------------------------------*/
#define DHCP_OP         0
#define DHCP_HTYPE      1
#define DHCP_HLEN       2
#define DHCP_HOPS       3
#define DHCP_XID        4
#define DHCP_SECS       8
#define DHCP_FLAGS     10
#define DHCP_CIADDR    12
#define DHCP_YIADDR    16
#define DHCP_SIADDR    20
#define DHCP_GIADDR    24
#define DHCP_CHADDR    28
#define DHCP_SNAME     44
#define DHCP_FILE     108
#define DHCP_OPTIONS  236

/* DHCP OPCODE VALUES {{{1 ---------------------------------------------------*/
#define DHCP_OP_BOOTREQUEST 1
#define DHCP_OP_BOOTREPLY   2

/* DHCP OPTIONS {{{1 ---------------------------------------------------------*/
/* Meaning None. [RFC2132] */
#define DHCP_OPTION_PAD                                         0
#define DHCP_OPTION_PAD_LEN                                     0
/* Meaning Subnet Mask Value. [RFC2132] */
#define DHCP_OPTION_SUBNET_MASK                                 1
#define DHCP_OPTION_SUBNET_MASK_LEN                             4
/* Meaning "Time Offset in Seconds from UTC (note: deprecated by 100 and 101)". [RFC2132] */
#define DHCP_OPTION_TIME_OFFSET                                 2
#define DHCP_OPTION_TIME_OFFSET_LEN                             4
/* Meaning N/4 Router addresses. [RFC2132] */
#define DHCP_OPTION_ROUTER                                      3
#define DHCP_OPTION_ROUTER_LEN                                  N
/* Meaning N/4 Timeserver addresses. [RFC2132] */
#define DHCP_OPTION_TIME_SERVER                                 4
#define DHCP_OPTION_TIME_SERVER_LEN                             N
/* Meaning N/4 IEN-116 Server addresses. [RFC2132] */
#define DHCP_OPTION_NAME_SERVER                                 5
#define DHCP_OPTION_NAME_SERVER_LEN                             N
/* Meaning N/4 DNS Server addresses. [RFC2132] */
#define DHCP_OPTION_DOMAIN_SERVER                               6
#define DHCP_OPTION_DOMAIN_SERVER_LEN                           N
/* Meaning N/4 Logging Server addresses. [RFC2132] */
#define DHCP_OPTION_LOG_SERVER                                  7
#define DHCP_OPTION_LOG_SERVER_LEN                              N
/* Meaning N/4 Quotes Server addresses. [RFC2132] */
#define DHCP_OPTION_QUOTES_SERVER                               8
#define DHCP_OPTION_QUOTES_SERVER_LEN                           N
/* Meaning N/4 Printer Server addresses. [RFC2132] */
#define DHCP_OPTION_LPR_SERVER                                  9
#define DHCP_OPTION_LPR_SERVER_LEN                              N
/* Meaning N/4 Impress Server addresses. [RFC2132] */
#define DHCP_OPTION_IMPRESS_SERVER                              10
#define DHCP_OPTION_IMPRESS_SERVER_LEN                          N
/* Meaning N/4 RLP Server addresses. [RFC2132] */
#define DHCP_OPTION_RLP_SERVER                                  11
#define DHCP_OPTION_RLP_SERVER_LEN                              N
/* Meaning Hostname string. [RFC2132] */
#define DHCP_OPTION_HOSTNAME                                    12
#define DHCP_OPTION_HOSTNAME_LEN                                N
/* Meaning Size of boot file in 512 byte chunks. [RFC2132] */
#define DHCP_OPTION_BOOT_FILE_SIZE                              13
#define DHCP_OPTION_BOOT_FILE_SIZE_LEN                          2
/* Meaning Client to dump and name the file to dump it to. [RFC2132] */
#define DHCP_OPTION_MERIT_DUMP_FILE                             14
#define DHCP_OPTION_MERIT_DUMP_FILE_LEN                         N
/* Meaning The DNS domain name of the client. [RFC2132] */
#define DHCP_OPTION_DOMAIN_NAME                                 15
#define DHCP_OPTION_DOMAIN_NAME_LEN                             N
/* Meaning Swap Server address. [RFC2132] */
#define DHCP_OPTION_SWAP_SERVER                                 16
#define DHCP_OPTION_SWAP_SERVER_LEN                             N
/* Meaning Path name for root disk. [RFC2132] */
#define DHCP_OPTION_ROOT_PATH                                   17
#define DHCP_OPTION_ROOT_PATH_LEN                               N
/* Meaning Path name for more BOOTP info. [RFC2132] */
#define DHCP_OPTION_EXTENSION_FILE                              18
#define DHCP_OPTION_EXTENSION_FILE_LEN                          N
/* Meaning Enable/Disable IP Forwarding. [RFC2132] */
#define DHCP_OPTION_FORWARD_ON_OFF                              19
#define DHCP_OPTION_FORWARD_ON_OFF_LEN                          1
/* Meaning Enable/Disable Source Routing. [RFC2132] */
#define DHCP_OPTION_SRCRTE_ON_OFF                               20
#define DHCP_OPTION_SRCRTE_ON_OFF_LEN                           1
/* Meaning Routing Policy Filters. [RFC2132] */
#define DHCP_OPTION_POLICY_FILTER                               21
#define DHCP_OPTION_POLICY_FILTER_LEN                           N
/* Meaning Max Datagram Reassembly Size. [RFC2132] */
#define DHCP_OPTION_MAX_DG_ASSEMBLY                             22
#define DHCP_OPTION_MAX_DG_ASSEMBLY_LEN                         2
/* Meaning Default IP Time to Live. [RFC2132] */
#define DHCP_OPTION_DEFAULT_IP_TTL                              23
#define DHCP_OPTION_DEFAULT_IP_TTL_LEN                          1
/* Meaning Path MTU Aging Timeout. [RFC2132] */
#define DHCP_OPTION_MTU_TIMEOUT                                 24
#define DHCP_OPTION_MTU_TIMEOUT_LEN                             4
/* Meaning Path MTU Plateau Table. [RFC2132] */
#define DHCP_OPTION_MTU_PLATEAU                                 25
#define DHCP_OPTION_MTU_PLATEAU_LEN                             N
/* Meaning Interface MTU Size. [RFC2132] */
#define DHCP_OPTION_MTU_INTERFACE                               26
#define DHCP_OPTION_MTU_INTERFACE_LEN                           2
/* Meaning All Subnets are Local. [RFC2132] */
#define DHCP_OPTION_MTU_SUBNET                                  27
#define DHCP_OPTION_MTU_SUBNET_LEN                              1
/* Meaning Broadcast Address. [RFC2132] */
#define DHCP_OPTION_BROADCAST_ADDRESS                           28
#define DHCP_OPTION_BROADCAST_ADDRESS_LEN                       4
/* Meaning Perform Mask Discovery. [RFC2132] */
#define DHCP_OPTION_MASK_DISCOVERY                              29
#define DHCP_OPTION_MASK_DISCOVERY_LEN                          1
/* Meaning Provide Mask to Others. [RFC2132] */
#define DHCP_OPTION_MASK_SUPPLIER                               30
#define DHCP_OPTION_MASK_SUPPLIER_LEN                           1
/* Meaning Perform Router Discovery. [RFC2132] */
#define DHCP_OPTION_ROUTER_DISCOVERY                            31
#define DHCP_OPTION_ROUTER_DISCOVERY_LEN                        1
/* Meaning Router Solicitation Address. [RFC2132] */
#define DHCP_OPTION_ROUTER_REQUEST                              32
#define DHCP_OPTION_ROUTER_REQUEST_LEN                          4
/* Meaning Static Routing Table. [RFC2132] */
#define DHCP_OPTION_STATIC_ROUTE                                33
#define DHCP_OPTION_STATIC_ROUTE_LEN                            N
/* Meaning Trailer Encapsulation. [RFC2132] */
#define DHCP_OPTION_TRAILERS                                    34
#define DHCP_OPTION_TRAILERS_LEN                                1
/* Meaning ARP Cache Timeout. [RFC2132] */
#define DHCP_OPTION_ARP_TIMEOUT                                 35
#define DHCP_OPTION_ARP_TIMEOUT_LEN                             4
/* Meaning Ethernet Encapsulation. [RFC2132] */
#define DHCP_OPTION_ETHERNET                                    36
#define DHCP_OPTION_ETHERNET_LEN                                1
/* Meaning Default TCP Time to Live. [RFC2132] */
#define DHCP_OPTION_DEFAULT_TCP_TTL                             37
#define DHCP_OPTION_DEFAULT_TCP_TTL_LEN                         1
/* Meaning TCP Keepalive Interval. [RFC2132] */
#define DHCP_OPTION_KEEPALIVE_TIME                              38
#define DHCP_OPTION_KEEPALIVE_TIME_LEN                          4
/* Meaning TCP Keepalive Garbage. [RFC2132] */
#define DHCP_OPTION_KEEPALIVE_DATA                              39
#define DHCP_OPTION_KEEPALIVE_DATA_LEN                          1
/* Meaning NIS Domain Name. [RFC2132] */
#define DHCP_OPTION_NIS_DOMAIN                                  40
#define DHCP_OPTION_NIS_DOMAIN_LEN                              N
/* Meaning NIS Server Addresses. [RFC2132] */
#define DHCP_OPTION_NIS_SERVERS                                 41
#define DHCP_OPTION_NIS_SERVERS_LEN                             N
/* Meaning NTP Server Addresses. [RFC2132] */
#define DHCP_OPTION_NTP_SERVERS                                 42
#define DHCP_OPTION_NTP_SERVERS_LEN                             N
/* Meaning Vendor Specific Information. [RFC2132] */
#define DHCP_OPTION_VENDOR_SPECIFIC                             43
#define DHCP_OPTION_VENDOR_SPECIFIC_LEN                         N
/* Meaning NETBIOS Name Servers. [RFC2132] */
#define DHCP_OPTION_NETBIOS_NAME_SRV                            44
#define DHCP_OPTION_NETBIOS_NAME_SRV_LEN                        N
/* Meaning NETBIOS Datagram Distribution. [RFC2132] */
#define DHCP_OPTION_NETBIOS_DIST_SRV                            45
#define DHCP_OPTION_NETBIOS_DIST_SRV_LEN                        N
/* Meaning NETBIOS Node Type. [RFC2132] */
#define DHCP_OPTION_NETBIOS_NODE_TYPE                           46
#define DHCP_OPTION_NETBIOS_NODE_TYPE_LEN                       1
/* Meaning NETBIOS Scope. [RFC2132] */
#define DHCP_OPTION_NETBIOS_SCOPE                               47
#define DHCP_OPTION_NETBIOS_SCOPE_LEN                           N
/* Meaning X Window Font Server. [RFC2132] */
#define DHCP_OPTION_X_WINDOW_FONT                               48
#define DHCP_OPTION_X_WINDOW_FONT_LEN                           N
/* Meaning X Window Display Manager. [RFC2132] */
#define DHCP_OPTION_X_WINDOW_MANAGER                            49
#define DHCP_OPTION_X_WINDOW_MANAGER_LEN                        N
/* Meaning Requested IP Address. [RFC2132] */
#define DHCP_OPTION_ADDRESS_REQUEST                             50
#define DHCP_OPTION_ADDRESS_REQUEST_LEN                         4
/* Meaning IP Address Lease Time. [RFC2132] */
#define DHCP_OPTION_ADDRESS_TIME                                51
#define DHCP_OPTION_ADDRESS_TIME_LEN                            4
/* Meaning "Overload ""sname"" or ""file""". [RFC2132] */
#define DHCP_OPTION_OVERLOAD                                    52
#define DHCP_OPTION_OVERLOAD_LEN                                1
/* Meaning DHCP Message Type. [RFC2132] */
#define DHCP_OPTION_DHCP_MSG_TYPE                               53
#define DHCP_OPTION_DHCP_MSG_TYPE_LEN                           1
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DISCOVER                 1
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_OFFER                    2
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_REQUEST                  3
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_DECLINE                  4
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_ACK                      5
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_NAK                      6
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_RELEASE                  7
#define DHCP_OPTION_DHCP_MSG_TYPE_DHCP_INFORM                   8
/* From RFC2132
9.6. DHCP Message Type

   This option is used to convey the type of the DHCP message.  The code
   for this option is 53, and its length is 1.  Legal values for this
   option are:

           Value   Message Type
           -----   ------------
             1     DHCPDISCOVER
             2     DHCPOFFER
             3     DHCPREQUEST
             4     DHCPDECLINE
             5     DHCPACK
             6     DHCPNAK
             7     DHCPRELEASE
             8     DHCPINFORM

    Code   Len  Type
   +-----+-----+-----+
   |  53 |  1  | 1-9 |
   +-----+-----+-----+
*/
/* Meaning DHCP Server Identification. [RFC2132] */
#define DHCP_OPTION_DHCP_SERVER_ID                              54
#define DHCP_OPTION_DHCP_SERVER_ID_LEN                          4
/* Meaning Parameter Request List. [RFC2132] */
#define DHCP_OPTION_PARAMETER_LIST                              55
#define DHCP_OPTION_PARAMETER_LIST_LEN                          N
/* Meaning DHCP Error Message. [RFC2132] */
#define DHCP_OPTION_DHCP_MESSAGE                                56
#define DHCP_OPTION_DHCP_MESSAGE_LEN                            N
/* Meaning DHCP Maximum Message Size. [RFC2132] */
#define DHCP_OPTION_DHCP_MAX_MSG_SIZE                           57
#define DHCP_OPTION_DHCP_MAX_MSG_SIZE_LEN                       2
/* Meaning DHCP Renewal (T1) Time. [RFC2132] */
#define DHCP_OPTION_RENEWAL_TIME                                58
#define DHCP_OPTION_RENEWAL_TIME_LEN                            4
/* Meaning DHCP Rebinding (T2) Time. [RFC2132] */
#define DHCP_OPTION_REBINDING_TIME                              59
#define DHCP_OPTION_REBINDING_TIME_LEN                          4
/* Meaning Class Identifier. [RFC2132] */
#define DHCP_OPTION_CLASS_ID                                    60
#define DHCP_OPTION_CLASS_ID_LEN                                N
/* Meaning Client Identifier. [RFC2132] */
#define DHCP_OPTION_CLIENT_ID                                   61
#define DHCP_OPTION_CLIENT_ID_LEN                               N
/* Meaning NetWare/IP Domain Name. [RFC2242] */
#define DHCP_OPTION_NETWARE_IP_DOMAIN                           62
#define DHCP_OPTION_NETWARE_IP_DOMAIN_LEN                       N
/* Meaning NetWare/IP sub Options. [RFC2242] */
#define DHCP_OPTION_NETWARE_IP_OPTION                           63
#define DHCP_OPTION_NETWARE_IP_OPTION_LEN                       N
/* Meaning NIS+ v3 Client Domain Name. [RFC2132] */
#define DHCP_OPTION_NIS_DOMAIN_NAME                             64
#define DHCP_OPTION_NIS_DOMAIN_NAME_LEN                         N
/* Meaning NIS+ v3 Server Addresses. [RFC2132] */
#define DHCP_OPTION_NIS_SERVER_ADDR                             65
#define DHCP_OPTION_NIS_SERVER_ADDR_LEN                         N
/* Meaning TFTP Server Name. [RFC2132] */
#define DHCP_OPTION_SERVER_NAME                                 66
#define DHCP_OPTION_SERVER_NAME_LEN                             N
/* Meaning Boot File Name. [RFC2132] */
#define DHCP_OPTION_BOOTFILE_NAME                               67
#define DHCP_OPTION_BOOTFILE_NAME_LEN                           N
/* Meaning Home Agent Addresses. [RFC2132] */
#define DHCP_OPTION_HOME_AGENT_ADDRS                            68
#define DHCP_OPTION_HOME_AGENT_ADDRS_LEN                        N
/* Meaning Simple Mail Server Addresses. [RFC2132] */
#define DHCP_OPTION_SMTP_SERVER                                 69
#define DHCP_OPTION_SMTP_SERVER_LEN                             N
/* Meaning Post Office Server Addresses. [RFC2132] */
#define DHCP_OPTION_POP3_SERVER                                 70
#define DHCP_OPTION_POP3_SERVER_LEN                             N
/* Meaning Network News Server Addresses. [RFC2132] */
#define DHCP_OPTION_NNTP_SERVER                                 71
#define DHCP_OPTION_NNTP_SERVER_LEN                             N
/* Meaning WWW Server Addresses. [RFC2132] */
#define DHCP_OPTION_WWW_SERVER                                  72
#define DHCP_OPTION_WWW_SERVER_LEN                              N
/* Meaning Finger Server Addresses. [RFC2132] */
#define DHCP_OPTION_FINGER_SERVER                               73
#define DHCP_OPTION_FINGER_SERVER_LEN                           N
/* Meaning Chat Server Addresses. [RFC2132] */
#define DHCP_OPTION_IRC_SERVER                                  74
#define DHCP_OPTION_IRC_SERVER_LEN                              N
/* Meaning StreetTalk Server Addresses. [RFC2132] */
#define DHCP_OPTION_STREETTALK_SERVER                           75
#define DHCP_OPTION_STREETTALK_SERVER_LEN                       N
/* Meaning ST Directory Assist. Addresses. [RFC2132] */
#define DHCP_OPTION_STDA_SERVER                                 76
#define DHCP_OPTION_STDA_SERVER_LEN                             N
/* Meaning User Class Information. [RFC3004] */
#define DHCP_OPTION_USER_CLASS                                  77
#define DHCP_OPTION_USER_CLASS_LEN                              N
/* Meaning directory agent information. [RFC2610] */
#define DHCP_OPTION_DIRECTORY_AGENT                             78
#define DHCP_OPTION_DIRECTORY_AGENT_LEN                         N
/* Meaning service location agent scope. [RFC2610] */
#define DHCP_OPTION_SERVICE_SCOPE                               79
#define DHCP_OPTION_SERVICE_SCOPE_LEN                           N
/* Meaning Rapid Commit. [RFC4039] */
#define DHCP_OPTION_RAPID_COMMIT                                80
#define DHCP_OPTION_RAPID_COMMIT_LEN                            0
/* Meaning Fully Qualified Domain Name. [RFC4702] */
#define DHCP_OPTION_CLIENT_FQDN                                 81
#define DHCP_OPTION_CLIENT_FQDN_LEN                             N
/* Meaning Relay Agent Information. [RFC3046] */
#define DHCP_OPTION_RELAY_AGENT_INFORMATION                     82
#define DHCP_OPTION_RELAY_AGENT_INFORMATION_LEN                 N
/* Meaning Internet Storage Name Service. [RFC4174] */
#define DHCP_OPTION_ISNS                                        83
#define DHCP_OPTION_ISNS_LEN                                    N
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          84
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning Novell Directory Services. [RFC2241] */
#define DHCP_OPTION_NDS_SERVERS                                 85
#define DHCP_OPTION_NDS_SERVERS_LEN                             N
/* Meaning Novell Directory Services. [RFC2241] */
#define DHCP_OPTION_NDS_TREE_NAME                               86
#define DHCP_OPTION_NDS_TREE_NAME_LEN                           N
/* Meaning Novell Directory Services. [RFC2241] */
#define DHCP_OPTION_NDS_CONTEXT                                 87
#define DHCP_OPTION_NDS_CONTEXT_LEN                             N
/* Meaning EMPTY. [RFC4280] */
#define DHCP_OPTION_BCMCS_CONTROLLER_DOMAIN_NAME_LIST           88
// #define DHCP_OPTION_BCMCS_CONTROLLER_DOMAIN_NAME_LIST_LEN
/* Meaning EMPTY. [RFC4280] */
#define DHCP_OPTION_BCMCS_CONTROLLER_IPV4_ADDRESS_OPTION        89
// #define DHCP_OPTION_BCMCS_CONTROLLER_IPV4_ADDRESS_OPTION_LEN
/* Meaning Authentication. [RFC3118] */
#define DHCP_OPTION_AUTHENTICATION                              90
#define DHCP_OPTION_AUTHENTICATION_LEN                          N
/* Meaning EMPTY. [RFC4388] */
#define DHCP_OPTION_CLIENT_LAST_TRANSACTION_TIME_OPTION         91
// #define DHCP_OPTION_CLIENT_LAST_TRANSACTION_TIME_OPTION_LEN
/* Meaning EMPTY. [RFC4388] */
#define DHCP_OPTION_ASSOCIATED_IP_OPTION                        92
// #define DHCP_OPTION_ASSOCIATED_IP_OPTION_LEN
/* Meaning Client System Architecture. [RFC4578] */
#define DHCP_OPTION_CLIENT_SYSTEM                               93
#define DHCP_OPTION_CLIENT_SYSTEM_LEN                           N
/* Meaning Client Network Device Interface. [RFC4578] */
#define DHCP_OPTION_CLIENT_NDI                                  94
#define DHCP_OPTION_CLIENT_NDI_LEN                              N
/* Meaning Lightweight Directory Access Protocol. [RFC3679] */
#define DHCP_OPTION_LDAP                                        95
#define DHCP_OPTION_LDAP_LEN                                    N
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          96
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning UUID/GUID-based Client Identifier. [RFC4578] */
#define DHCP_OPTION_UUID_GUID                                   97
#define DHCP_OPTION_UUID_GUID_LEN                               N
/* Meaning Open Group's User Authentication. [RFC2485] */
#define DHCP_OPTION_USER_AUTH                                   98
#define DHCP_OPTION_USER_AUTH_LEN                               N
/* Meaning EMPTY. [RFC4776] */
#define DHCP_OPTION_GEOCONF_CIVIC                               99
// #define DHCP_OPTION_GEOCONF_CIVIC_LEN
/* Meaning IEEE 1003.1 TZ String. [RFC4833] */
#define DHCP_OPTION_PCODE                                       100
#define DHCP_OPTION_PCODE_LEN                                   N
/* Meaning Reference to the TZ Database. [RFC4833] */
#define DHCP_OPTION_TCODE                                       101
#define DHCP_OPTION_TCODE_LEN                                   N
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          102-107
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          108
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning DHCPv4 over DHCPv6 Softwire Source Address Option. [RFC-ietf-dhc-dhcp4o6-saddr-opt-08] */
#define DHCP_OPTION_OPTION_DHCP4O6_S46_SADDR                    109
#define DHCP_OPTION_OPTION_DHCP4O6_S46_SADDR_LEN                16
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          110
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_UNASSIGNED                                  111
// #define DHCP_OPTION_UNASSIGNED_LEN
/* Meaning NetInfo Parent Server Address. [RFC3679] */
#define DHCP_OPTION_NETINFO_ADDRESS                             112
#define DHCP_OPTION_NETINFO_ADDRESS_LEN                         N
/* Meaning NetInfo Parent Server Tag. [RFC3679] */
#define DHCP_OPTION_NETINFO_TAG                                 113
#define DHCP_OPTION_NETINFO_TAG_LEN                             N
/* Meaning URL. [RFC3679] */
#define DHCP_OPTION_URL                                         114
#define DHCP_OPTION_URL_LEN                                     N
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          115
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning DHCP Auto-Configuration. [RFC2563] */
#define DHCP_OPTION_AUTO_CONFIG                                 116
#define DHCP_OPTION_AUTO_CONFIG_LEN                             N
/* Meaning Name Service Search. [RFC2937] */
#define DHCP_OPTION_NAME_SERVICE_SEARCH                         117
#define DHCP_OPTION_NAME_SERVICE_SEARCH_LEN                     N
/* Meaning Subnet Selection Option. [RFC3011] */
#define DHCP_OPTION_SUBNET_SELECTION_OPTION                     118
#define DHCP_OPTION_SUBNET_SELECTION_OPTION_LEN                 4
/* Meaning DNS domain search list. [RFC3397] */
#define DHCP_OPTION_DOMAIN_SEARCH                               119
#define DHCP_OPTION_DOMAIN_SEARCH_LEN                           N
/* Meaning SIP Servers DHCP Option. [RFC3361] */
#define DHCP_OPTION_SIP_SERVERS_DHCP_OPTION                     120
#define DHCP_OPTION_SIP_SERVERS_DHCP_OPTION_LEN                 N
/* Meaning Classless Static Route Option. [RFC3442] */
#define DHCP_OPTION_CLASSLESS_STATIC_ROUTE_OPTION               121
#define DHCP_OPTION_CLASSLESS_STATIC_ROUTE_OPTION_LEN           N
/* Meaning CableLabs Client Configuration. [RFC3495] */
#define DHCP_OPTION_CCC                                         122
#define DHCP_OPTION_CCC_LEN                                     N
/* Meaning GeoConf Option. [RFC6225] */
#define DHCP_OPTION_GEOCONF_OPTION                              123
#define DHCP_OPTION_GEOCONF_OPTION_LEN                          16
/* Meaning Vendor-Identifying Vendor Class. [RFC3925] */
#define DHCP_OPTION_V_I_VENDOR_CLASS                            124
// #define DHCP_OPTION_V_I_VENDOR_CLASS_LEN
/* Meaning Vendor-Identifying Vendor-Specific Information. [RFC3925] */
#define DHCP_OPTION_V_I_VENDOR_SPECIFIC_INFORMATION             125
// #define DHCP_OPTION_V_I_VENDOR_SPECIFIC_INFORMATION_LEN
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          126
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning EMPTY. [RFC3679] */
// #define DHCP_OPTION_REMOVED_UNASSIGNED                          127
// #define DHCP_OPTION_REMOVED_UNASSIGNED_LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            128
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_ETHERBOOT_SIGNATURE__6_BYTES__E4_45_74_68_00_00 128
// #define DHCP_OPTION_ETHERBOOT_SIGNATURE__6_BYTES__E4_45_74_68_00_00_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_DOCSIS___FULL_SECURITY___SERVER_IP_ADDRESS  128
// #define DHCP_OPTION_DOCSIS___FULL_SECURITY___SERVER_IP_ADDRESS_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_TFTP_SERVER_IP_ADDRESS__FOR_IP_PHONE_SOFTWARE_LOAD_ 128
// #define DHCP_OPTION_TFTP_SERVER_IP_ADDRESS__FOR_IP_PHONE_SOFTWARE_LOAD__LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            129
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_KERNEL_OPTIONS__VARIABLE_LENGTH_STRING      129
// #define DHCP_OPTION_KERNEL_OPTIONS__VARIABLE_LENGTH_STRING_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_CALL_SERVER_IP_ADDRESS                      129
// #define DHCP_OPTION_CALL_SERVER_IP_ADDRESS_LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            130
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_ETHERNET_INTERFACE__VARIABLE_LENGTH_STRING_ 130
// #define DHCP_OPTION_ETHERNET_INTERFACE__VARIABLE_LENGTH_STRING__LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_DISCRIMINATION_STRING__TO_IDENTIFY_VENDOR_  130
// #define DHCP_OPTION_DISCRIMINATION_STRING__TO_IDENTIFY_VENDOR__LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            131
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_REMOTE_STATISTICS_SERVER_IP_ADDRESS         131
// #define DHCP_OPTION_REMOTE_STATISTICS_SERVER_IP_ADDRESS_LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            132
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_IEEE_802_1Q_VLAN_ID                         132
// #define DHCP_OPTION_IEEE_802_1Q_VLAN_ID_LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            133
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_IEEE_802_1D_P_LAYER_2_PRIORITY              133
// #define DHCP_OPTION_IEEE_802_1D_P_LAYER_2_PRIORITY_LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            134
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_DIFFSERV_CODE_POINT__DSCP__FOR_VOIP_SIGNALLING_AND_MEDIA_STREAMS 134
// #define DHCP_OPTION_DIFFSERV_CODE_POINT__DSCP__FOR_VOIP_SIGNALLING_AND_MEDIA_STREAMS_LEN
/* Meaning EMPTY. [RFC4578] */
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC            135
// #define DHCP_OPTION_PXE___UNDEFINED__VENDOR_SPECIFIC_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_HTTP_PROXY_FOR_PHONE_SPECIFIC_APPLICATIONS  135
// #define DHCP_OPTION_HTTP_PROXY_FOR_PHONE_SPECIFIC_APPLICATIONS_LEN
/* Meaning EMPTY. [RFC5192] */
#define DHCP_OPTION_OPTION_PANA_AGENT                           136
// #define DHCP_OPTION_OPTION_PANA_AGENT_LEN
/* Meaning EMPTY. [RFC5223] */
#define DHCP_OPTION_OPTION_V4_LOST                              137
// #define DHCP_OPTION_OPTION_V4_LOST_LEN
/* Meaning CAPWAP Access Controller addresses. [RFC5417] */
#define DHCP_OPTION_OPTION_CAPWAP_AC_V4                         138
#define DHCP_OPTION_OPTION_CAPWAP_AC_V4_LEN                     N
/* Meaning a series of suboptions. [RFC5678] */
#define DHCP_OPTION_OPTION_IPV4_ADDRESS_MOS                     139
#define DHCP_OPTION_OPTION_IPV4_ADDRESS_MOS_LEN                 N
/* Meaning a series of suboptions. [RFC5678] */
#define DHCP_OPTION_OPTION_IPV4_FQDN_MOS                        140
#define DHCP_OPTION_OPTION_IPV4_FQDN_MOS_LEN                    N
/* Meaning List of domain names to search for SIP User Agent Configuration. [RFC6011] */
#define DHCP_OPTION_SIP_UA_CONFIGURATION_SERVICE_DOMAINS        141
#define DHCP_OPTION_SIP_UA_CONFIGURATION_SERVICE_DOMAINS_LEN    N
/* Meaning ANDSF IPv4 Address Option for DHCPv4. [RFC6153] */
#define DHCP_OPTION_OPTION_IPV4_ADDRESS_ANDSF                   142
#define DHCP_OPTION_OPTION_IPV4_ADDRESS_ANDSF_LEN               N
/* Meaning This option provides a list of URIs for SZTP bootstrap server100 10504 0 10504 0 0 11404 0 --:--:-- --:--:-- --:--:-- 11392 s. [RFC-ietf-netconf-zerotouch-29] */
#define DHCP_OPTION_OPTION_V4_SZTP_REDIRECT                     143
#define DHCP_OPTION_OPTION_V4_SZTP_REDIRECT_LEN                 N
/* Meaning Geospatial Location with Uncertainty. [RFC6225] */
#define DHCP_OPTION_GEOLOC                                      144
#define DHCP_OPTION_GEOLOC_LEN                                  16
/* Meaning Forcerenew Nonce Capable. [RFC6704] */
#define DHCP_OPTION_FORCERENEW_NONCE_CAPABLE                    145
#define DHCP_OPTION_FORCERENEW_NONCE_CAPABLE_LEN                1
/* Meaning Information for selecting RDNSS. [RFC6731] */
#define DHCP_OPTION_RDNSS_SELECTION                             146
#define DHCP_OPTION_RDNSS_SELECTION_LEN                         N
/* Meaning EMPTY. [RFC3942] */
// #define DHCP_OPTION_UNASSIGNED                                  147-149
// #define DHCP_OPTION_UNASSIGNED_LEN
/* Meaning EMPTY. [RFC5859] */
#define DHCP_OPTION_TFTP_SERVER_ADDRESS                         150
// #define DHCP_OPTION_TFTP_SERVER_ADDRESS_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_ETHERBOOT                                   150
// #define DHCP_OPTION_ETHERBOOT_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_GRUB_CONFIGURATION_PATH_NAME                150
// #define DHCP_OPTION_GRUB_CONFIGURATION_PATH_NAME_LEN
/* Meaning Status code and optional N byte text message describing status.. [RFC6926] */
#define DHCP_OPTION_STATUS_CODE                                 151
#define DHCP_OPTION_STATUS_CODE_LEN                             N+1
/* Meaning "Absolute time (seconds since Jan 1.  1970) message was sent." */
#define DHCP_OPTION_BASE_TIME                                   152
#define DHCP_OPTION_BASE_TIME_LEN                               4
/* Meaning Number of seconds in the past when client entered current state.. [RFC6926] */
#define DHCP_OPTION_START_TIME_OF_STATE                         153
#define DHCP_OPTION_START_TIME_OF_STATE_LEN                     4
/* Meaning "Absolute time (seconds since Jan 1.  1970) for beginning of query." */
#define DHCP_OPTION_QUERY_START_TIME                            154
#define DHCP_OPTION_QUERY_START_TIME_LEN                        4
/* Meaning "Absolute time (seconds since Jan 1.  1970) for end of query." */
#define DHCP_OPTION_QUERY_END_TIME                              155
#define DHCP_OPTION_QUERY_END_TIME_LEN                          4
/* Meaning State of IP address.. [RFC6926] */
#define DHCP_OPTION_DHCP_STATE                                  156
#define DHCP_OPTION_DHCP_STATE_LEN                              1
/* Meaning Indicates information came from local or remote server.. [RFC6926] */
#define DHCP_OPTION_DATA_SOURCE                                 157
#define DHCP_OPTION_DATA_SOURCE_LEN                             1
/* Meaning "Includes one or multiple lists of PCP server IP addresses; each list is treated as a separate PCP server.". [RFC7291] */
#define DHCP_OPTION_OPTION_V4_PCP_SERVER                        158
#define DHCP_OPTION_OPTION_V4_PCP_SERVER_LEN                    Variable; the minimum length is 5.
/* Meaning "This option is used to configure a set of ports bound to a shared IPv4 address.". [RFC7618] */
#define DHCP_OPTION_OPTION_V4_PORTPARAMS                        159
#define DHCP_OPTION_OPTION_V4_PORTPARAMS_LEN                    4
/* Meaning DHCP Captive-Portal. [RFC7710] */
#define DHCP_OPTION_DHCP_CAPTIVE_PORTAL                         160
#define DHCP_OPTION_DHCP_CAPTIVE_PORTAL_LEN                     N
/* Meaning Manufacturer Usage Descriptions. [RFC-ietf-opsawg-mud-25] */
#define DHCP_OPTION_OPTION_MUD_URL_V4                           161
#define DHCP_OPTION_OPTION_MUD_URL_V4_LEN                       N (variable)
/* Meaning EMPTY. [RFC3942] */
// #define DHCP_OPTION_UNASSIGNED                                  162-174
// #define DHCP_OPTION_UNASSIGNED_LEN
/* Meaning EMPTY.  */
// #define DHCP_OPTION_ETHERBOOT__TENTATIVELY_ASSIGNED___2005_06_23_ 175
// #define DHCP_OPTION_ETHERBOOT__TENTATIVELY_ASSIGNED___2005_06_23__LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_IP_TELEPHONE__TENTATIVELY_ASSIGNED___2005_06_23_ 176
// #define DHCP_OPTION_IP_TELEPHONE__TENTATIVELY_ASSIGNED___2005_06_23__LEN
/* Meaning EMPTY.  */
// #define DHCP_OPTION_ETHERBOOT__TENTATIVELY_ASSIGNED___2005_06_23_ 177
// #define DHCP_OPTION_ETHERBOOT__TENTATIVELY_ASSIGNED___2005_06_23__LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_PACKETCABLE_AND_CABLEHOME__REPLACED_BY_122_ 177
// #define DHCP_OPTION_PACKETCABLE_AND_CABLEHOME__REPLACED_BY_122__LEN
/* Meaning EMPTY. [RFC3942] */
// #define DHCP_OPTION_UNASSIGNED                                  178-207
// #define DHCP_OPTION_UNASSIGNED_LEN
/* Meaning magic string = F1:00:74:7E. [RFC5071][Deprecated] */
#define DHCP_OPTION_PXELINUX_MAGIC                              208
#define DHCP_OPTION_PXELINUX_MAGIC_LEN                          4
/* Meaning Configuration file. [RFC5071] */
#define DHCP_OPTION_CONFIGURATION_FILE                          209
#define DHCP_OPTION_CONFIGURATION_FILE_LEN                      N
/* Meaning Path Prefix Option. [RFC5071] */
#define DHCP_OPTION_PATH_PREFIX                                 210
#define DHCP_OPTION_PATH_PREFIX_LEN                             N
/* Meaning Reboot Time. [RFC5071] */
#define DHCP_OPTION_REBOOT_TIME                                 211
#define DHCP_OPTION_REBOOT_TIME_LEN                             4
/* Meaning OPTION_6RD with N/4 6rd BR addresses. [RFC5969] */
#define DHCP_OPTION_OPTION_6RD                                  212
#define DHCP_OPTION_OPTION_6RD_LEN                              18 + N
/* Meaning Access Network Domain Name. [RFC5986] */
#define DHCP_OPTION_OPTION_V4_ACCESS_DOMAIN                     213
#define DHCP_OPTION_OPTION_V4_ACCESS_DOMAIN_LEN                 N
/* Meaning EMPTY.  */
// #define DHCP_OPTION_UNASSIGNED                                  214-219
// #define DHCP_OPTION_UNASSIGNED_LEN
/* Meaning Subnet Allocation Option. [RFC6656] */
#define DHCP_OPTION_SUBNET_ALLOCATION_OPTION                    220
#define DHCP_OPTION_SUBNET_ALLOCATION_OPTION_LEN                N
/* Meaning EMPTY. [RFC6607] */
#define DHCP_OPTION_VIRTUAL_SUBNET_SELECTION__VSS__OPTION       221
// #define DHCP_OPTION_VIRTUAL_SUBNET_SELECTION__VSS__OPTION_LEN
/* Meaning EMPTY. [RFC3942] */
// #define DHCP_OPTION_UNASSIGNED                                  222-223
// #define DHCP_OPTION_UNASSIGNED_LEN
/* Meaning EMPTY.  */
#define DHCP_OPTION_RESERVED__PRIVATE_USE                       224-254
// #define DHCP_OPTION_RESERVED__PRIVATE_USE_LEN
/* Meaning None. [RFC2132] */
#define DHCP_OPTION_END                                         255
#define DHCP_OPTION_END_LEN                                     0

/* DHCP Options and BOOTP Vendor Extensions {{{1 -------------------------------
   [[1]Docs] [[2]txt|[3]pdf] [[4]draft-ietf-dhc-...] [[5]Tracker]
   [[6]Diff1] [[7]Diff2] [[8]Errata]
   Updated by: [9]3442, [10]3942, [11]4361, [12]4833, [13]5494 DRAFT
   STANDARD
   Errata Exist
Network Working Group                                       S. Alexander
Request for Comments: 2132                        Silicon Graphics, Inc.
Obsoletes: [14]1533                                                 R. Droms
Category: Standards Track                            Bucknell University
                                                              March 1997

                DHCP Options and BOOTP Vendor Extensions

Status of this memo

   This document specifies an Internet standards track protocol for the
   Internet community, and requests discussion and suggestions for
   improvements.  Please refer to the current edition of the "Internet
   Official Protocol Standards" (STD 1) for the standardization state
   and status of this protocol.  Distribution of this memo is unlimited.

Abstract

   The Dynamic Host Configuration Protocol (DHCP) [[15]1] provides a
   framework for passing configuration information to hosts on a TCP/IP
   network.  Configuration parameters and other control information are
   carried in tagged data items that are stored in the 'options' field
   of the DHCP message.  The data items themselves are also called
   "options."

   This document specifies the current set of DHCP options.  Future
   options will be specified in separate RFCs.  The current list of
   valid options is also available in [16]ftp://ftp.isi.edu/in-
   [17]notes/iana/assignments [[18]22].

   All of the vendor information extensions defined in [19]RFC 1497 [[20]2] may
   be used as DHCP options.  The definitions given in [21]RFC 1497 are
   included in this document, which supersedes [22]RFC 1497.  All of the
   DHCP options defined in this document, except for those specific to
   DHCP as defined in [23]section 9, may be used as BOOTP vendor information
   extensions.

Table of Contents

    [24]1.  Introduction ..............................................  [25]2
    [26]2.  BOOTP Extension/DHCP Option Field Format ..................  [27]4
    [28]3.  [29]RFC 1497 Vendor Extensions ................................  [30
]5
    [31]4.  IP Layer Parameters per Host .............................. [32]11
    [33]5.  IP Layer Parameters per Interface ........................  [34]13
    [35]6.  Link Layer Parameters per Interface ....................... [36]16
    [37]7.  TCP Parameters ............................................ [38]17
    [39]8.  Application and Service Parameters ........................ [40]18
    [41]9.  DHCP Extensions ........................................... [42]25



Alexander & Droms           Standards Track                     [Page 1]
   __________________________________________________________________


[43]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   [44]10.  Defining new extensions ................................... [45]31
   [46]11.  Acknowledgements .......................................... [47]31
   [48]12.  References ................................................ [49]32
   [50]13.  Security Considerations ................................... [51]33
   [52]14.  Authors' Addresses ........................................ [53]34

[54]1. Introduction

   This document specifies options for use with both the Dynamic Host
   Configuration Protocol and the Bootstrap Protocol.

   The full description of DHCP packet formats may be found in the DHCP
   specification document [[55]1], and the full description of BOOTP packet
   formats may be found in the BOOTP specification document [[56]3].  This
   document defines the format of information in the last field of DHCP
   packets ('options') and of BOOTP packets ('vend').  The remainder of
   this section defines a generalized use of this area for giving
   information useful to a wide class of machines, operating systems and
   configurations. Sites with a single DHCP or BOOTP server that is
   shared among heterogeneous clients may choose to define other, site-
   specific formats for the use of the 'options' field.

   [57]Section 2 of this memo describes the formats of DHCP options and
   BOOTP vendor extensions.  [58]Section 3 describes options defined in
   previous documents for use with BOOTP (all may also be used with
   DHCP).  Sections [59]4-[60]8 define new options intended for use with both
   DHCP and BOOTP. [61]Section 9 defines options used only in DHCP.

   References further describing most of the options defined in sections
   2-6 can be found in [62]section 12.  The use of the options defined in
   [63]section 9 is described in the DHCP specification [[64]1].

   Information on registering new options is contained in [65]section 10.

   This document updates the definition of DHCP/BOOTP options that
   appears in [66]RFC1533.  The classing mechanism has been extended to
   include vendor classes as described in [67]section 8.4 and 9.13.  The new
   procedure for defining new DHCP/BOOTP options in described in [68]section
   [69]10.  Several new options, including NIS+ domain and servers, Mobile
   IP home agent, SMTP server, TFTP server and Bootfile server, have
   been added.  Text giving definitions used throughout the document has
   been added in [70]section 1.1.  Text emphasizing the need for uniqueness
   of client-identifiers has been added to [71]section 9.14.








Alexander & Droms           Standards Track                     [Page 2]
   __________________________________________________________________


[72]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[73]1.1 Requirements

   Throughout this document, the words that are used to define the
   significance of particular requirements are capitalized.  These words
   are:

      o "MUST"

       This word or the adjective "REQUIRED" means that the item is an
       absolute requirement of this specification.

      o "MUST NOT"

       This phrase means that the item is an absolute prohibition of
       this specification.

      o "SHOULD"

       This word or the adjective "RECOMMENDED" means that there may
       exist valid reasons in particular circumstances to ignore this
       item, but the full implications should be understood and the case
       carefully weighed before choosing a different course.

      o "SHOULD NOT"

       This phrase means that there may exist valid reasons in
       particular circumstances when the listed behavior is acceptable
       or even useful, but the full implications should be understood
       and the case carefully weighed before implementing any behavior
       described with this label.

      o "MAY"

       This word or the adjective "OPTIONAL" means that this item is
       truly optional.  One vendor may choose to include the item
       because a particular marketplace requires it or because it
       enhances the product, for example; another vendor may omit the
       same item.

[74]1.2 Terminology

   This document uses the following terms:

      o "DHCP client"

       A DHCP client or "client" is an Internet host using DHCP to
       obtain configuration parameters such as a network address.




Alexander & Droms           Standards Track                     [Page 3]
   __________________________________________________________________


[75]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


      o "DHCP server"

       A DHCP server of "server"is an Internet host that returns
       configuration parameters to DHCP clients.

      o "binding"

       A binding is a collection of configuration parameters, including
       at least an IP address, associated with or "bound to" a DHCP
       client.  Bindings are managed by DHCP servers.

[76]2. BOOTP Extension/DHCP Option Field Format


   DHCP options have the same format as the BOOTP 'vendor extensions'
   defined in [77]RFC 1497 [[78]2].  Options may be fixed length or variable
   length.  All options begin with a tag octet, which uniquely
   identifies the option.  Fixed-length options without data consist of
   only a tag octet.  Only options 0 and 255 are fixed length.  All
   other options are variable-length with a length octet following the
   tag octet.  The value of the length octet does not include the two
   octets specifying the tag and length.  The length octet is followed
   by "length" octets of data.  Options containing NVT ASCII data SHOULD
   NOT include a trailing NULL; however, the receiver of such options
   MUST be prepared to delete trailing nulls if they exist.  The
   receiver MUST NOT require that a trailing null be included in the
   data.  In the case of some variable-length options the length field
   is a constant but must still be specified.

   Any options defined subsequent to this document MUST contain a length
   octet even if the length is fixed or zero.

   All multi-octet quantities are in network byte-order.

   When used with BOOTP, the first four octets of the vendor information
   field have been assigned to the "magic cookie" (as suggested in [79]RFC
   [80]951).  This field identifies the mode in which the succeeding data is
   to be interpreted.  The value of the magic cookie is the 4 octet
   dotted decimal 99.130.83.99 (or hexadecimal number 63.82.53.63) in
   network byte order.

   All of the "vendor extensions" defined in [81]RFC 1497 are also DHCP
   options.

   Option codes 128 to 254 (decimal) are reserved for site-specific
   options.





Alexander & Droms           Standards Track                     [Page 4]
   __________________________________________________________________


[82]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   Except for the options in [83]section 9, all options may be used with
   either DHCP or BOOTP.

   Many of these options have their default values specified in other
   documents.  In particular, [84]RFC 1122 [[85]4] specifies default values for
   most IP and TCP configuration parameters.

   Many options supply one or more 32-bit IP address.  Use of IP
   addresses rather than fully-qualified Domain Names (FQDNs) may make
   future renumbering of IP hosts more difficult.  Use of these
   addresses is discouraged at sites that may require renumbering.

[86]3. [87]RFC 1497 Vendor Extensions

   This section lists the vendor extensions as defined in [88]RFC 1497.
   They are defined here for completeness.

[89]3.1. Pad Option

   The pad option can be used to cause subsequent fields to align on
   word boundaries.

   The code for the pad option is 0, and its length is 1 octet.

    Code
   +-----+
   |  0  |
   +-----+

[90]3.2. End Option

   The end option marks the end of valid information in the vendor
   field.  Subsequent octets should be filled with pad options.

   The code for the end option is 255, and its length is 1 octet.

    Code
   +-----+
   | 255 |
   +-----+

[91]3.3. Subnet Mask

   The subnet mask option specifies the client's subnet mask as per [92]RFC
   [93]950 [[94]5].

   If both the subnet mask and the router option are specified in a DHCP
   reply, the subnet mask option MUST be first.



Alexander & Droms           Standards Track                     [Page 5]
   __________________________________________________________________


[95]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for the subnet mask option is 1, and its length is 4 octets.

    Code   Len        Subnet Mask
   +-----+-----+-----+-----+-----+-----+
   |  1  |  4  |  m1 |  m2 |  m3 |  m4 |
   +-----+-----+-----+-----+-----+-----+

[96]3.4. Time Offset

   The time offset field specifies the offset of the client's subnet in
   seconds from Coordinated Universal Time (UTC).  The offset is
   expressed as a two's complement 32-bit integer.  A positive offset
   indicates a location east of the zero meridian and a negative offset
   indicates a location west of the zero meridian.

   The code for the time offset option is 2, and its length is 4 octets.

    Code   Len        Time Offset
   +-----+-----+-----+-----+-----+-----+
   |  2  |  4  |  n1 |  n2 |  n3 |  n4 |
   +-----+-----+-----+-----+-----+-----+

[97]3.5. Router Option

   The router option specifies a list of IP addresses for routers on the
   client's subnet.  Routers SHOULD be listed in order of preference.

   The code for the router option is 3.  The minimum length for the
   router option is 4 octets, and the length MUST always be a multiple
   of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  3  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[98]3.6. Time Server Option

   The time server option specifies a list of [99]RFC 868 [[100]6] time servers
   available to the client.  Servers SHOULD be listed in order of
   preference.

   The code for the time server option is 4.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.






Alexander & Droms           Standards Track                     [Page 6]
   __________________________________________________________________


[101]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  4  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[102]3.7. Name Server Option

   The name server option specifies a list of IEN 116 [[103]7] name servers
   available to the client.  Servers SHOULD be listed in order of
   preference.

   The code for the name server option is 5.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  5  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[104]3.8. Domain Name Server Option

   The domain name server option specifies a list of Domain Name System
   (STD 13, [105]RFC 1035 [[106]8]) name servers available to the client.  Serve
rs
   SHOULD be listed in order of preference.

   The code for the domain name server option is 6.  The minimum length
   for this option is 4 octets, and the length MUST always be a multiple
   of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  6  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[107]3.9. Log Server Option

   The log server option specifies a list of MIT-LCS UDP log servers
   available to the client.  Servers SHOULD be listed in order of
   preference.

   The code for the log server option is 7.  The minimum length for this
   option is 4 octets, and the length MUST always be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  7  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--



Alexander & Droms           Standards Track                     [Page 7]
   __________________________________________________________________


[108]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[109]3.10. Cookie Server Option

   The cookie server option specifies a list of [110]RFC 865 [[111]9] cookie
   servers available to the client.  Servers SHOULD be listed in order
   of preference.

   The code for the log server option is 8.  The minimum length for this
   option is 4 octets, and the length MUST always be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  8  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[112]3.11. LPR Server Option

   The LPR server option specifies a list of [113]RFC 1179 [[114]10] line printe
r
   servers available to the client.  Servers SHOULD be listed in order
   of preference.

   The code for the LPR server option is 9.  The minimum length for this
   option is 4 octets, and the length MUST always be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  9  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[115]3.12. Impress Server Option

   The Impress server option specifies a list of Imagen Impress servers
   available to the client.  Servers SHOULD be listed in order of
   preference.

   The code for the Impress server option is 10.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  10 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[116]3.13. Resource Location Server Option

   This option specifies a list of [117]RFC 887 [[118]11] Resource Location
   servers available to the client.  Servers SHOULD be listed in order
   of preference.



Alexander & Droms           Standards Track                     [Page 8]
   __________________________________________________________________


[119]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for this option is 11.  The minimum length for this option
   is 4 octets, and the length MUST always be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  11 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[120]3.14. Host Name Option

   This option specifies the name of the client.  The name may or may
   not be qualified with the local domain name (see [121]section 3.17 for the
   preferred way to retrieve the domain name).  See [122]RFC 1035 for
   character set restrictions.

   The code for this option is 12, and its minimum length is 1.

    Code   Len                 Host Name
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  12 |  n  |  h1 |  h2 |  h3 |  h4 |  h5 |  h6 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[123]3.15. Boot File Size Option

   This option specifies the length in 512-octet blocks of the default
   boot image for the client.  The file length is specified as an
   unsigned 16-bit integer.

   The code for this option is 13, and its length is 2.

    Code   Len   File Size
   +-----+-----+-----+-----+
   |  13 |  2  |  l1 |  l2 |
   +-----+-----+-----+-----+

[124]3.16. Merit Dump File

   This option specifies the path-name of a file to which the client's
   core image should be dumped in the event the client crashes.  The
   path is formatted as a character string consisting of characters from
   the NVT ASCII character set.

   The code for this option is 14.  Its minimum length is 1.

    Code   Len      Dump File Pathname
   +-----+-----+-----+-----+-----+-----+---
   |  14 |  n  |  n1 |  n2 |  n3 |  n4 | ...
   +-----+-----+-----+-----+-----+-----+---



Alexander & Droms           Standards Track                     [Page 9]
   __________________________________________________________________


[125]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[126]3.17. Domain Name

   This option specifies the domain name that client should use when
   resolving hostnames via the Domain Name System.

   The code for this option is 15.  Its minimum length is 1.

    Code   Len        Domain Name
   +-----+-----+-----+-----+-----+-----+--
   |  15 |  n  |  d1 |  d2 |  d3 |  d4 |  ...
   +-----+-----+-----+-----+-----+-----+--

[127]3.18. Swap Server

   This specifies the IP address of the client's swap server.

   The code for this option is 16 and its length is 4.

    Code   Len    Swap Server Address
   +-----+-----+-----+-----+-----+-----+
   |  16 |  n  |  a1 |  a2 |  a3 |  a4 |
   +-----+-----+-----+-----+-----+-----+

[128]3.19. Root Path

   This option specifies the path-name that contains the client's root
   disk.  The path is formatted as a character string consisting of
   characters from the NVT ASCII character set.

   The code for this option is 17.  Its minimum length is 1.

    Code   Len      Root Disk Pathname
   +-----+-----+-----+-----+-----+-----+---
   |  17 |  n  |  n1 |  n2 |  n3 |  n4 | ...
   +-----+-----+-----+-----+-----+-----+---

[129]3.20. Extensions Path

   A string to specify a file, retrievable via TFTP, which contains
   information which can be interpreted in the same way as the 64-octet
   vendor-extension field within the BOOTP response, with the following
   exceptions:

          - the length of the file is unconstrained;
          - all references to Tag 18 (i.e., instances of the
            BOOTP Extensions Path field) within the file are
            ignored.




Alexander & Droms           Standards Track                    [Page 10]
   __________________________________________________________________


[130]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for this option is 18.  Its minimum length is 1.

    Code   Len      Extensions Pathname
   +-----+-----+-----+-----+-----+-----+---
   |  18 |  n  |  n1 |  n2 |  n3 |  n4 | ...
   +-----+-----+-----+-----+-----+-----+---

[131]4. IP Layer Parameters per Host

   This section details the options that affect the operation of the IP
   layer on a per-host basis.

[132]4.1. IP Forwarding Enable/Disable Option

   This option specifies whether the client should configure its IP
   layer for packet forwarding.  A value of 0 means disable IP
   forwarding, and a value of 1 means enable IP forwarding.

   The code for this option is 19, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  19 |  1  | 0/1 |
   +-----+-----+-----+

[133]4.2. Non-Local Source Routing Enable/Disable Option

   This option specifies whether the client should configure its IP
   layer to allow forwarding of datagrams with non-local source routes
   (see Section 3.3.5 of [[134]4] for a discussion of this topic).  A value
   of 0 means disallow forwarding of such datagrams, and a value of 1
   means allow forwarding.

   The code for this option is 20, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  20 |  1  | 0/1 |
   +-----+-----+-----+

[135]4.3. Policy Filter Option

   This option specifies policy filters for non-local source routing.
   The filters consist of a list of IP addresses and masks which specify
   destination/mask pairs with which to filter incoming source routes.

   Any source routed datagram whose next-hop address does not match one
   of the filters should be discarded by the client.



Alexander & Droms           Standards Track                    [Page 11]
   __________________________________________________________________


[136]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   See [[137]4] for further information.

   The code for this option is 21.  The minimum length of this option is
   8, and the length MUST be a multiple of 8.

    Code   Len         Address 1                  Mask 1
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
   |  21 |  n  |  a1 |  a2 |  a3 |  a4 |  m1 |  m2 |  m3 |  m4 |
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
           Address 2                  Mask 2
   +-----+-----+-----+-----+-----+-----+-----+-----+---
   |  a1 |  a2 |  a3 |  a4 |  m1 |  m2 |  m3 |  m4 | ...
   +-----+-----+-----+-----+-----+-----+-----+-----+---

[138]4.4. Maximum Datagram Reassembly Size

   This option specifies the maximum size datagram that the client
   should be prepared to reassemble.  The size is specified as a 16-bit
   unsigned integer.  The minimum value legal value is 576.

   The code for this option is 22, and its length is 2.

    Code   Len      Size
   +-----+-----+-----+-----+
   |  22 |  2  |  s1 |  s2 |
   +-----+-----+-----+-----+

[139]4.5. Default IP Time-to-live

   This option specifies the default time-to-live that the client should
   use on outgoing datagrams.  The TTL is specified as an octet with a
   value between 1 and 255.

   The code for this option is 23, and its length is 1.

    Code   Len   TTL
   +-----+-----+-----+
   |  23 |  1  | ttl |
   +-----+-----+-----+

[140]4.6. Path MTU Aging Timeout Option

   This option specifies the timeout (in seconds) to use when aging Path
   MTU values discovered by the mechanism defined in [141]RFC 1191 [[142]12].  T
he
   timeout is specified as a 32-bit unsigned integer.

   The code for this option is 24, and its length is 4.




Alexander & Droms           Standards Track                    [Page 12]
   __________________________________________________________________


[143]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


    Code   Len           Timeout
   +-----+-----+-----+-----+-----+-----+
   |  24 |  4  |  t1 |  t2 |  t3 |  t4 |
   +-----+-----+-----+-----+-----+-----+

[144]4.7. Path MTU Plateau Table Option

   This option specifies a table of MTU sizes to use when performing
   Path MTU Discovery as defined in [145]RFC 1191.  The table is formatted as
   a list of 16-bit unsigned integers, ordered from smallest to largest.
   The minimum MTU value cannot be smaller than 68.

   The code for this option is 25.  Its minimum length is 2, and the
   length MUST be a multiple of 2.

    Code   Len     Size 1      Size 2
   +-----+-----+-----+-----+-----+-----+---
   |  25 |  n  |  s1 |  s2 |  s1 |  s2 | ...
   +-----+-----+-----+-----+-----+-----+---

[146]5. IP Layer Parameters per Interface

   This section details the options that affect the operation of the IP
   layer on a per-interface basis.  It is expected that a client can
   issue multiple requests, one per interface, in order to configure
   interfaces with their specific parameters.

[147]5.1. Interface MTU Option

   This option specifies the MTU to use on this interface.  The MTU is
   specified as a 16-bit unsigned integer.  The minimum legal value for
   the MTU is 68.

   The code for this option is 26, and its length is 2.

    Code   Len      MTU
   +-----+-----+-----+-----+
   |  26 |  2  |  m1 |  m2 |
   +-----+-----+-----+-----+

[148]5.2. All Subnets are Local Option

   This option specifies whether or not the client may assume that all
   subnets of the IP network to which the client is connected use the
   same MTU as the subnet of that network to which the client is
   directly connected.  A value of 1 indicates that all subnets share
   the same MTU.  A value of 0 means that the client should assume that
   some subnets of the directly connected network may have smaller MTUs.



Alexander & Droms           Standards Track                    [Page 13]
   __________________________________________________________________


[149]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for this option is 27, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  27 |  1  | 0/1 |
   +-----+-----+-----+

[150]5.3. Broadcast Address Option

   This option specifies the broadcast address in use on the client's
   subnet.  Legal values for broadcast addresses are specified in
   section 3.2.1.3 of [[151]4].

   The code for this option is 28, and its length is 4.

    Code   Len     Broadcast Address
   +-----+-----+-----+-----+-----+-----+
   |  28 |  4  |  b1 |  b2 |  b3 |  b4 |
   +-----+-----+-----+-----+-----+-----+

[152]5.4. Perform Mask Discovery Option

   This option specifies whether or not the client should perform subnet
   mask discovery using ICMP.  A value of 0 indicates that the client
   should not perform mask discovery.  A value of 1 means that the
   client should perform mask discovery.

   The code for this option is 29, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  29 |  1  | 0/1 |
   +-----+-----+-----+

[153]5.5. Mask Supplier Option

   This option specifies whether or not the client should respond to
   subnet mask requests using ICMP.  A value of 0 indicates that the
   client should not respond.  A value of 1 means that the client should
   respond.

   The code for this option is 30, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  30 |  1  | 0/1 |
   +-----+-----+-----+




Alexander & Droms           Standards Track                    [Page 14]
   __________________________________________________________________


[154]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[155]5.6. Perform Router Discovery Option

   This option specifies whether or not the client should solicit
   routers using the Router Discovery mechanism defined in [156]RFC 1256
   [[157]13].  A value of 0 indicates that the client should not perform
   router discovery.  A value of 1 means that the client should perform
   router discovery.

   The code for this option is 31, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  31 |  1  | 0/1 |
   +-----+-----+-----+

[158]5.7. Router Solicitation Address Option

   This option specifies the address to which the client should transmit
   router solicitation requests.

   The code for this option is 32, and its length is 4.

    Code   Len            Address
   +-----+-----+-----+-----+-----+-----+
   |  32 |  4  |  a1 |  a2 |  a3 |  a4 |
   +-----+-----+-----+-----+-----+-----+

[159]5.8. Static Route Option

   This option specifies a list of static routes that the client should
   install in its routing cache.  If multiple routes to the same
   destination are specified, they are listed in descending order of
   priority.

   The routes consist of a list of IP address pairs.  The first address
   is the destination address, and the second address is the router for
   the destination.

   The default route (0.0.0.0) is an illegal destination for a static
   route.  See [160]section 3.5 for information about the router option.

   The code for this option is 33.  The minimum length of this option is
   8, and the length MUST be a multiple of 8.








Alexander & Droms           Standards Track                    [Page 15]
   __________________________________________________________________


[161]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


    Code   Len         Destination 1           Router 1
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
   |  33 |  n  |  d1 |  d2 |  d3 |  d4 |  r1 |  r2 |  r3 |  r4 |
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
           Destination 2           Router 2
   +-----+-----+-----+-----+-----+-----+-----+-----+---
   |  d1 |  d2 |  d3 |  d4 |  r1 |  r2 |  r3 |  r4 | ...
   +-----+-----+-----+-----+-----+-----+-----+-----+---

[162]6. Link Layer Parameters per Interface

   This section lists the options that affect the operation of the data
   link layer on a per-interface basis.

[163]6.1. Trailer Encapsulation Option

   This option specifies whether or not the client should negotiate the
   use of trailers ([164]RFC 893 [[165]14]) when using the ARP protocol.  A valu
e
   of 0 indicates that the client should not attempt to use trailers.  A
   value of 1 means that the client should attempt to use trailers.

   The code for this option is 34, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  34 |  1  | 0/1 |
   +-----+-----+-----+

[166]6.2. ARP Cache Timeout Option

   This option specifies the timeout in seconds for ARP cache entries.
   The time is specified as a 32-bit unsigned integer.

   The code for this option is 35, and its length is 4.

    Code   Len           Time
   +-----+-----+-----+-----+-----+-----+
   |  35 |  4  |  t1 |  t2 |  t3 |  t4 |
   +-----+-----+-----+-----+-----+-----+

[167]6.3. Ethernet Encapsulation Option

   This option specifies whether or not the client should use Ethernet
   Version 2 ([168]RFC 894 [[169]15]) or IEEE 802.3 ([170]RFC 1042 [[171]16]) en
capsulation
   if the interface is an Ethernet.  A value of 0 indicates that the
   client should use [172]RFC 894 encapsulation.  A value of 1 means that the
   client should use [173]RFC 1042 encapsulation.




Alexander & Droms           Standards Track                    [Page 16]
   __________________________________________________________________


[174]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for this option is 36, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  36 |  1  | 0/1 |
   +-----+-----+-----+

[175]7. TCP Parameters

   This section lists the options that affect the operation of the TCP
   layer on a per-interface basis.

[176]7.1. TCP Default TTL Option

   This option specifies the default TTL that the client should use when
   sending TCP segments.  The value is represented as an 8-bit unsigned
   integer.  The minimum value is 1.

   The code for this option is 37, and its length is 1.

    Code   Len   TTL
   +-----+-----+-----+
   |  37 |  1  |  n  |
   +-----+-----+-----+

[177]7.2. TCP Keepalive Interval Option

   This option specifies the interval (in seconds) that the client TCP
   should wait before sending a keepalive message on a TCP connection.
   The time is specified as a 32-bit unsigned integer.  A value of zero
   indicates that the client should not generate keepalive messages on
   connections unless specifically requested by an application.

   The code for this option is 38, and its length is 4.

    Code   Len           Time
   +-----+-----+-----+-----+-----+-----+
   |  38 |  4  |  t1 |  t2 |  t3 |  t4 |
   +-----+-----+-----+-----+-----+-----+

[178]7.3. TCP Keepalive Garbage Option

   This option specifies the whether or not the client should send TCP
   keepalive messages with a octet of garbage for compatibility with
   older implementations.  A value of 0 indicates that a garbage octet
   should not be sent. A value of 1 indicates that a garbage octet
   should be sent.




Alexander & Droms           Standards Track                    [Page 17]
   __________________________________________________________________


[179]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for this option is 39, and its length is 1.

    Code   Len  Value
   +-----+-----+-----+
   |  39 |  1  | 0/1 |
   +-----+-----+-----+

[180]8. Application and Service Parameters

   This section details some miscellaneous options used to configure
   miscellaneous applications and services.

[181]8.1. Network Information Service Domain Option

   This option specifies the name of the client's NIS [[182]17] domain.  The
   domain is formatted as a character string consisting of characters
   from the NVT ASCII character set.

   The code for this option is 40.  Its minimum length is 1.

    Code   Len      NIS Domain Name
   +-----+-----+-----+-----+-----+-----+---
   |  40 |  n  |  n1 |  n2 |  n3 |  n4 | ...
   +-----+-----+-----+-----+-----+-----+---

[183]8.2. Network Information Servers Option

   This option specifies a list of IP addresses indicating NIS servers
   available to the client.  Servers SHOULD be listed in order of
   preference.

   The code for this option is 41.  Its minimum length is 4, and the
   length MUST be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  41 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[184]8.3. Network Time Protocol Servers Option

   This option specifies a list of IP addresses indicating NTP [[185]18]
   servers available to the client.  Servers SHOULD be listed in order
   of preference.

   The code for this option is 42.  Its minimum length is 4, and the
   length MUST be a multiple of 4.




Alexander & Droms           Standards Track                    [Page 18]
   __________________________________________________________________


[186]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  42 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[187]8.4. Vendor Specific Information

   This option is used by clients and servers to exchange vendor-
   specific information.  The information is an opaque object of n
   octets, presumably interpreted by vendor-specific code on the clients
   and servers.  The definition of this information is vendor specific.
   The vendor is indicated in the vendor class identifier option.
   Servers not equipped to interpret the vendor-specific information
   sent by a client MUST ignore it (although it may be reported).
   Clients which do not receive desired vendor-specific information
   SHOULD make an attempt to operate without it, although they may do so
   (and announce they are doing so) in a degraded mode.

   If a vendor potentially encodes more than one item of information in
   this option, then the vendor SHOULD encode the option using
   "Encapsulated vendor-specific options" as described below:

   The Encapsulated vendor-specific options field SHOULD be encoded as a
   sequence of code/length/value fields of identical syntax to the DHCP
   options field with the following exceptions:

      1) There SHOULD NOT be a "magic cookie" field in the encapsulated
         vendor-specific extensions field.

      2) Codes other than 0 or 255 MAY be redefined by the vendor within
         the encapsulated vendor-specific extensions field, but SHOULD
         conform to the tag-length-value syntax defined in [188]section 2.

      3) Code 255 (END), if present, signifies the end of the
         encapsulated vendor extensions, not the end of the vendor
         extensions field. If no code 255 is present, then the end of
         the enclosing vendor-specific information field is taken as the
         end of the encapsulated vendor-specific extensions field.

   The code for this option is 43 and its minimum length is 1.

   Code   Len   Vendor-specific information
   +-----+-----+-----+-----+---
   |  43 |  n  |  i1 |  i2 | ...
   +-----+-----+-----+-----+---






Alexander & Droms           Standards Track                    [Page 19]
   __________________________________________________________________


[189]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   When encapsulated vendor-specific extensions are used, the
   information bytes 1-n have the following format:

    Code   Len   Data item        Code   Len   Data item       Code
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
   |  T1 |  n  |  d1 |  d2 | ... |  T2 |  n  |  D1 |  D2 | ... | ... |
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+

[190]8.5. NetBIOS over TCP/IP Name Server Option

   The NetBIOS name server (NBNS) option specifies a list of [191]RFC
   [192]1001/1002 [[193]19] [[194]20] NBNS name servers listed in order of prefe
rence.

   The code for this option is 44.  The minimum length of the option is
   4 octets, and the length must always be a multiple of 4.

    Code   Len           Address 1              Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+----
   |  44 |  n  |  a1 |  a2 |  a3 |  a4 |  b1 |  b2 |  b3 |  b4 | ...
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+----

[195]8.6. NetBIOS over TCP/IP Datagram Distribution Server Option

   The NetBIOS datagram distribution server (NBDD) option specifies a
   list of [196]RFC 1001/1002 NBDD servers listed in order of preference. The
   code for this option is 45.  The minimum length of the option is 4
   octets, and the length must always be a multiple of 4.

    Code   Len           Address 1              Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+----
   |  45 |  n  |  a1 |  a2 |  a3 |  a4 |  b1 |  b2 |  b3 |  b4 | ...
   +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+----

[197]8.7. NetBIOS over TCP/IP Node Type Option

   The NetBIOS node type option allows NetBIOS over TCP/IP clients which
   are configurable to be configured as described in [198]RFC 1001/1002.  The
   value is specified as a single octet which identifies the client type
   as follows:

      Value         Node Type
      -----         ---------
      0x1           B-node
      0x2           P-node
      0x4           M-node
      0x8           H-node





Alexander & Droms           Standards Track                    [Page 20]
   __________________________________________________________________


[199]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   In the above chart, the notation '0x' indicates a number in base-16
   (hexadecimal).

   The code for this option is 46.  The length of this option is always
   1.

    Code   Len  Node Type
   +-----+-----+-----------+
   |  46 |  1  | see above |
   +-----+-----+-----------+

[200]8.8. NetBIOS over TCP/IP Scope Option

   The NetBIOS scope option specifies the NetBIOS over TCP/IP scope
   parameter for the client as specified in [201]RFC 1001/1002. See [[202]19],
   [[203]20], and [[204]8] for character-set restrictions.

   The code for this option is 47.  The minimum length of this option is
   1.

    Code   Len       NetBIOS Scope
   +-----+-----+-----+-----+-----+-----+----
   |  47 |  n  |  s1 |  s2 |  s3 |  s4 | ...
   +-----+-----+-----+-----+-----+-----+----

[205]8.9. X Window System Font Server Option

   This option specifies a list of X Window System [[206]21] Font servers
   available to the client. Servers SHOULD be listed in order of
   preference.

   The code for this option is 48.  The minimum length of this option is
   4 octets, and the length MUST be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+---
   |  48 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |   ...
   +-----+-----+-----+-----+-----+-----+-----+-----+---

[207]8.10. X Window System Display Manager Option

   This option specifies a list of IP addresses of systems that are
   running the X Window System Display Manager and are available to the
   client.

   Addresses SHOULD be listed in order of preference.





Alexander & Droms           Standards Track                    [Page 21]
   __________________________________________________________________


[208]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for the this option is 49. The minimum length of this option
   is 4, and the length MUST be a multiple of 4.

    Code   Len         Address 1               Address 2

   +-----+-----+-----+-----+-----+-----+-----+-----+---
   |  49 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |   ...
   +-----+-----+-----+-----+-----+-----+-----+-----+---

[209]8.11. Network Information Service+ Domain Option

   This option specifies the name of the client's NIS+ [[210]17] domain.  The
   domain is formatted as a character string consisting of characters
   from the NVT ASCII character set.

   The code for this option is 64.  Its minimum length is 1.

    Code   Len      NIS Client Domain Name
   +-----+-----+-----+-----+-----+-----+---
   |  64 |  n  |  n1 |  n2 |  n3 |  n4 | ...
   +-----+-----+-----+-----+-----+-----+---

[211]8.12. Network Information Service+ Servers Option

   This option specifies a list of IP addresses indicating NIS+ servers
   available to the client.  Servers SHOULD be listed in order of
   preference.

   The code for this option is 65.  Its minimum length is 4, and the
   length MUST be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   |  65 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[212]8.13. Mobile IP Home Agent option

   This option specifies a list of IP addresses indicating mobile IP
   home agents available to the client.  Agents SHOULD be listed in
   order of preference.

   The code for this option is 68.  Its minimum length is 0 (indicating
   no home agents are available) and the length MUST be a multiple of 4.
   It is expected that the usual length will be four octets, containing
   a single home agent's address.





Alexander & Droms           Standards Track                    [Page 22]
   __________________________________________________________________


[213]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


    Code Len    Home Agent Addresses (zero or more)
   +-----+-----+-----+-----+-----+-----+--
   | 68  |  n  | a1  | a2  | a3  | a4  | ...
   +-----+-----+-----+-----+-----+-----+--

[214]8.14. Simple Mail Transport Protocol (SMTP) Server Option

   The SMTP server option specifies a list of SMTP servers available to
   the client.  Servers SHOULD be listed in order of preference.

   The code for the SMTP server option is 69.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 69  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[215]8.15. Post Office Protocol (POP3) Server Option

   The POP3 server option specifies a list of POP3 available to the
   client.  Servers SHOULD be listed in order of preference.

   The code for the POP3 server option is 70.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 70  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[216]8.16. Network News Transport Protocol (NNTP) Server Option

   The NNTP server option specifies a list of NNTP available to the
   client.  Servers SHOULD be listed in order of preference.

   The code for the NNTP server option is 71. The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 71  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--





Alexander & Droms           Standards Track                    [Page 23]
   __________________________________________________________________


[217]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[218]8.17. Default World Wide Web (WWW) Server Option

   The WWW server option specifies a list of WWW available to the
   client.  Servers SHOULD be listed in order of preference.

   The code for the WWW server option is 72.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 72  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[219]8.18. Default Finger Server Option

   The Finger server option specifies a list of Finger available to the
   client.  Servers SHOULD be listed in order of preference.

   The code for the Finger server option is 73.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 73  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[220]8.19. Default Internet Relay Chat (IRC) Server Option

   The IRC server option specifies a list of IRC available to the
   client.  Servers SHOULD be listed in order of preference.

   The code for the IRC server option is 74.  The minimum length for
   this option is 4 octets, and the length MUST always be a multiple of
   4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 74  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[221]8.20. StreetTalk Server Option

   The StreetTalk server option specifies a list of StreetTalk servers
   available to the client.  Servers SHOULD be listed in order of
   preference.




Alexander & Droms           Standards Track                    [Page 24]
   __________________________________________________________________


[222]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for the StreetTalk server option is 75.  The minimum length
   for this option is 4 octets, and the length MUST always be a multiple
   of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 75  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[223]8.21. StreetTalk Directory Assistance (STDA) Server Option

   The StreetTalk Directory Assistance (STDA) server option specifies a
   list of STDA servers available to the client.  Servers SHOULD be
   listed in order of preference.

   The code for the StreetTalk Directory Assistance server option is 76.
   The minimum length for this option is 4 octets, and the length MUST
   always be a multiple of 4.

    Code   Len         Address 1               Address 2
   +-----+-----+-----+-----+-----+-----+-----+-----+--
   | 76  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
   +-----+-----+-----+-----+-----+-----+-----+-----+--

[224]9. DHCP Extensions

   This section details the options that are specific to DHCP.

[225]9.1. Requested IP Address

   This option is used in a client request (DHCPDISCOVER) to allow the
   client to request that a particular IP address be assigned.

   The code for this option is 50, and its length is 4.

    Code   Len          Address
   +-----+-----+-----+-----+-----+-----+
   |  50 |  4  |  a1 |  a2 |  a3 |  a4 |
   +-----+-----+-----+-----+-----+-----+

[226]9.2. IP Address Lease Time

   This option is used in a client request (DHCPDISCOVER or DHCPREQUEST)
   to allow the client to request a lease time for the IP address.  In a
   server reply (DHCPOFFER), a DHCP server uses this option to specify
   the lease time it is willing to offer.





Alexander & Droms           Standards Track                    [Page 25]
   __________________________________________________________________


[227]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The time is in units of seconds, and is specified as a 32-bit
   unsigned integer.

   The code for this option is 51, and its length is 4.

    Code   Len         Lease Time
   +-----+-----+-----+-----+-----+-----+
   |  51 |  4  |  t1 |  t2 |  t3 |  t4 |
   +-----+-----+-----+-----+-----+-----+

[228]9.3. Option Overload

   This option is used to indicate that the DHCP 'sname' or 'file'
   fields are being overloaded by using them to carry DHCP options. A
   DHCP server inserts this option if the returned parameters will
   exceed the usual space allotted for options.

   If this option is present, the client interprets the specified
   additional fields after it concludes interpretation of the standard
   option fields.

   The code for this option is 52, and its length is 1.  Legal values
   for this option are:

           Value   Meaning
           -----   --------
             1     the 'file' field is used to hold options
             2     the 'sname' field is used to hold options
             3     both fields are used to hold options

    Code   Len  Value
   +-----+-----+-----+
   |  52 |  1  |1/2/3|
   +-----+-----+-----+

[229]9.4 TFTP server name

   This option is used to identify a TFTP server when the 'sname' field
   in the DHCP header has been used for DHCP options.

   The code for this option is 66, and its minimum length is 1.

       Code  Len   TFTP server
      +-----+-----+-----+-----+-----+---
      | 66  |  n  |  c1 |  c2 |  c3 | ...
      +-----+-----+-----+-----+-----+---





Alexander & Droms           Standards Track                    [Page 26]
   __________________________________________________________________


[230]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[231]9.5 Bootfile name

   This option is used to identify a bootfile when the 'file' field in
   the DHCP header has been used for DHCP options.

   The code for this option is 67, and its minimum length is 1.

       Code  Len   Bootfile name
      +-----+-----+-----+-----+-----+---
      | 67  |  n  |  c1 |  c2 |  c3 | ...
      +-----+-----+-----+-----+-----+---

[232]9.6. DHCP Message Type

   This option is used to convey the type of the DHCP message.  The code
   for this option is 53, and its length is 1.  Legal values for this
   option are:

           Value   Message Type
           -----   ------------
             1     DHCPDISCOVER
             2     DHCPOFFER
             3     DHCPREQUEST
             4     DHCPDECLINE
             5     DHCPACK
             6     DHCPNAK
             7     DHCPRELEASE
             8     DHCPINFORM

    Code   Len  Type
   +-----+-----+-----+
   |  53 |  1  | 1-9 |
   +-----+-----+-----+

[233]9.7. Server Identifier

   This option is used in DHCPOFFER and DHCPREQUEST messages, and may
   optionally be included in the DHCPACK and DHCPNAK messages.  DHCP
   servers include this option in the DHCPOFFER in order to allow the
   client to distinguish between lease offers.  DHCP clients use the
   contents of the 'server identifier' field as the destination address
   for any DHCP messages unicast to the DHCP server.  DHCP clients also
   indicate which of several lease offers is being accepted by including
   this option in a DHCPREQUEST message.

   The identifier is the IP address of the selected server.

   The code for this option is 54, and its length is 4.



Alexander & Droms           Standards Track                    [Page 27]
   __________________________________________________________________


[234]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


    Code   Len            Address
   +-----+-----+-----+-----+-----+-----+
   |  54 |  4  |  a1 |  a2 |  a3 |  a4 |
   +-----+-----+-----+-----+-----+-----+

[235]9.8. Parameter Request List

   This option is used by a DHCP client to request values for specified
   configuration parameters.  The list of requested parameters is
   specified as n octets, where each octet is a valid DHCP option code
   as defined in this document.

   The client MAY list the options in order of preference.  The DHCP
   server is not required to return the options in the requested order,
   but MUST try to insert the requested options in the order requested
   by the client.

   The code for this option is 55.  Its minimum length is 1.

    Code   Len   Option Codes
   +-----+-----+-----+-----+---
   |  55 |  n  |  c1 |  c2 | ...
   +-----+-----+-----+-----+---

[236]9.9. Message

   This option is used by a DHCP server to provide an error message to a
   DHCP client in a DHCPNAK message in the event of a failure. A client
   may use this option in a DHCPDECLINE message to indicate the why the
   client declined the offered parameters.  The message consists of n
   octets of NVT ASCII text, which the client may display on an
   available output device.

   The code for this option is 56 and its minimum length is 1.

    Code   Len     Text
   +-----+-----+-----+-----+---
   |  56 |  n  |  c1 |  c2 | ...
   +-----+-----+-----+-----+---

[237]9.10. Maximum DHCP Message Size

   This option specifies the maximum length DHCP message that it is
   willing to accept.  The length is specified as an unsigned 16-bit
   integer.  A client may use the maximum DHCP message size option in
   DHCPDISCOVER or DHCPREQUEST messages, but should not use the option
   in DHCPDECLINE messages.




Alexander & Droms           Standards Track                    [Page 28]
   __________________________________________________________________


[238]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The code for this option is 57, and its length is 2.  The minimum
   legal value is 576 octets.

    Code   Len     Length
   +-----+-----+-----+-----+
   |  57 |  2  |  l1 |  l2 |
   +-----+-----+-----+-----+

[239]9.11. Renewal (T1) Time Value

   This option specifies the time interval from address assignment until
   the client transitions to the RENEWING state.

   The value is in units of seconds, and is specified as a 32-bit
   unsigned integer.

   The code for this option is 58, and its length is 4.

    Code   Len         T1 Interval
   +-----+-----+-----+-----+-----+-----+
   |  58 |  4  |  t1 |  t2 |  t3 |  t4 |
   +-----+-----+-----+-----+-----+-----+

[240]9.12. Rebinding (T2) Time Value

   This option specifies the time interval from address assignment until
   the client transitions to the REBINDING state.

   The value is in units of seconds, and is specified as a 32-bit
   unsigned integer.

   The code for this option is 59, and its length is 4.

    Code   Len         T2 Interval
   +-----+-----+-----+-----+-----+-----+
   |  59 |  4  |  t1 |  t2 |  t3 |  t4 |
   +-----+-----+-----+-----+-----+-----+

[241]9.13. Vendor class identifier

   This option is used by DHCP clients to optionally identify the vendor
   type and configuration of a DHCP client.  The information is a string
   of n octets, interpreted by servers.  Vendors may choose to define
   specific vendor class identifiers to convey particular configuration
   or other identification information about a client.  For example, the
   identifier may encode the client's hardware configuration.  Servers
   not equipped to interpret the class-specific information sent by a
   client MUST ignore it (although it may be reported). Servers that



Alexander & Droms           Standards Track                    [Page 29]
   __________________________________________________________________


[242]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   respond SHOULD only use option 43 to return the vendor-specific
   information to the client.

   The code for this option is 60, and its minimum length is 1.

   Code   Len   Vendor class Identifier
   +-----+-----+-----+-----+---
   |  60 |  n  |  i1 |  i2 | ...
   +-----+-----+-----+-----+---

[243]9.14. Client-identifier

   This option is used by DHCP clients to specify their unique
   identifier.  DHCP servers use this value to index their database of
   address bindings.  This value is expected to be unique for all
   clients in an administrative domain.

   Identifiers SHOULD be treated as opaque objects by DHCP servers.

   The client identifier MAY consist of type-value pairs similar to the
   'htype'/'chaddr' fields defined in [[244]3]. For instance, it MAY consist
   of a hardware type and hardware address. In this case the type field
   SHOULD be one of the ARP hardware types defined in STD2 [[245]22].  A
   hardware type of 0 (zero) should be used when the value field
   contains an identifier other than a hardware address (e.g. a fully
   qualified domain name).

   For correct identification of clients, each client's client-
   identifier MUST be unique among the client-identifiers used on the
   subnet to which the client is attached.  Vendors and system
   administrators are responsible for choosing client-identifiers that
   meet this requirement for uniqueness.

   The code for this option is 61, and its minimum length is 2.

   Code   Len   Type  Client-Identifier
   +-----+-----+-----+-----+-----+---
   |  61 |  n  |  t1 |  i1 |  i2 | ...
   +-----+-----+-----+-----+-----+---












Alexander & Droms           Standards Track                    [Page 30]
   __________________________________________________________________


[246]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[247]10. Defining new extensions

   The author of a new DHCP option will follow these steps to obtain
   acceptance of the option as a part of the DHCP Internet Standard:

   1. The author devises the new option.
   2. The author requests a number for the new option from IANA by
      contacting:
      Internet Assigned Numbers Authority (IANA)
      USC/Information Sciences Institute
      4676 Admiralty Way
      Marina del Rey, California  90292-6695

      or by email as: iana@iana.org

   3. The author documents the new option, using the newly obtained
      option number, as an Internet Draft.
   4. The author submits the Internet Draft for review through the IETF
      standards process as defined in "Internet Official Protocol
      Standards" (STD 1).  The new option will be submitted for eventual
      acceptance as an Internet Standard.
   5. The new option progresses through the IETF standards process; the
      new option will be reviewed by the Dynamic Host Configuration
      Working Group (if that group still exists), or as an Internet
      Draft not submitted by an IETF working group.
   6. If the new option fails to gain acceptance as an Internet
      Standard, the assigned option number will be returned to IANA for
      reassignment.

      This procedure for defining new extensions will ensure that:

      * allocation of new option numbers is coordinated from a single
        authority,
      * new options are reviewed for technical correctness and
        appropriateness, and
      * documentation for new options is complete and published.

[248]11. Acknowledgements

   The author thanks the many (and too numerous to mention!) members of
   the DHC WG for their tireless and ongoing efforts in the development
   of DHCP and this document.

   The efforts of J Allard, Mike Carney, Dave Lapp, Fred Lien and John
   Mendonca in organizing DHCP interoperability testing sessions are
   gratefully acknowledged.





Alexander & Droms           Standards Track                    [Page 31]
   __________________________________________________________________


[249]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   The development of this document was supported in part by grants from
   the Corporation for National Research Initiatives (CNRI), Bucknell
   University and Sun Microsystems.

[250]12. References

   [1] Droms, R., "Dynamic Host Configuration Protocol", [251]RFC 2131,
       Bucknell University, March 1997.

   [2] Reynolds, J., "BOOTP Vendor Information Extensions", [252]RFC 1497,
       USC/Information Sciences Institute, August 1993.

   [3] Croft, W., and J. Gilmore, "Bootstrap Protocol", [253]RFC 951,
       Stanford University and Sun Microsystems, September 1985.

   [4] Braden, R., Editor, "Requirements for Internet Hosts -
       Communication Layers", STD 3, [254]RFC 1122, USC/Information Sciences
       Institute, October 1989.

   [5] Mogul, J., and J. Postel, "Internet Standard Subnetting
       Procedure", STD 5, [255]RFC 950, USC/Information Sciences Institute,
       August 1985.

   [6] Postel, J., and K. Harrenstien, "Time Protocol", STD 26, [256]RFC
       [257]868, USC/Information Sciences Institute, SRI, May 1983.

   [7] Postel, J., "Name Server", IEN 116, USC/Information Sciences
       Institute, August 1979.

   [8] Mockapetris, P., "Domain Names - Implementation and
       Specification", STD 13, [258]RFC 1035, USC/Information Sciences
       Institute, November 1987.

   [9] Postel, J., "Quote of the Day Protocol", STD 23, [259]RFC 865,
       USC/Information Sciences Institute, May 1983.

   [10] McLaughlin, L., "Line Printer Daemon Protocol", [260]RFC 1179, The
        Wollongong Group, August 1990.

   [11] Accetta, M., "Resource Location Protocol", [261]RFC 887, CMU,
        December 1983.

   [12] Mogul, J. and S. Deering, "Path MTU Discovery", [262]RFC 1191,
        DECWRL,  Stanford University, November 1990.

   [13] Deering, S., "ICMP Router Discovery Messages", [263]RFC 1256,
        Xerox PARC, September 1991.




Alexander & Droms           Standards Track                    [Page 32]
   __________________________________________________________________


[264]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


   [14] Leffler, S. and M. Karels, "Trailer Encapsulations", [265]RFC 893,
        U. C. Berkeley, April 1984.

   [15] Hornig, C., "Standard for the Transmission of IP Datagrams over
        Ethernet Networks", [266]RFC 894, Symbolics, April 1984.

   [16] Postel, J. and J. Reynolds, "Standard for the Transmission of
        IP Datagrams Over IEEE 802 Networks", [267]RFC 1042,  USC/Information
        Sciences Institute, February 1988.

   [17] Sun Microsystems, "System and Network Administration", March
        1990.

   [18] Mills, D., "Internet Time Synchronization: The Network Time
        Protocol", [268]RFC 1305, UDEL, March 1992.

   [19] NetBIOS Working Group, "Protocol Standard for a NetBIOS Service
        on a TCP/UDP transport: Concepts and Methods", STD 19, [269]RFC 1001,
        March 1987.

   [20] NetBIOS Working Group, "Protocol Standard for a NetBIOS Service
        on a TCP/UDP transport: Detailed Specifications", STD 19, [270]RFC
        [271]1002, March 1987.

   [21] Scheifler, R., "FYI On the X Window System", FYI 6, [272]RFC 1198,
        MIT Laboratory for Computer Science, January 1991.

   [22] Reynolds, J., and J. Postel, "Assigned Numbers", STD 2, [273]RFC 1700,
        USC/Information Sciences Institute, July 1992.

[274]13. Security Considerations

   Security issues are not discussed in this memo.


















Alexander & Droms           Standards Track                    [Page 33]
   __________________________________________________________________


[275]RFC 2132        DHCP Options and BOOTP Vendor Extensions      March 1997


[276]14. Authors' Addresses

   Steve Alexander
   Silicon Graphics, Inc.
   2011 N. Shoreline Boulevard
   Mailstop 510
   Mountain View, CA 94043-1389

   Phone: (415) 933-6172
   EMail: sca@engr.sgi.com


   Ralph Droms
   Bucknell University
   Lewisburg, PA 17837

   Phone: (717) 524-1145
   EMail: droms@bucknell.edu

Alexander & Droms           Standards Track                    [Page 34]
}}}1 */

#endif
