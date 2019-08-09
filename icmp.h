/* vim: set foldmethod=marker: */
#ifndef _ICMP_H_
#define _ICMP_H_

/* https://tools.ietf.org/html/rfc792 */
/* ICMP packet {{{1 ------------------------------------------------------------
 *    0               1               2               3
 *    0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
 *   +---------------+---------------+-------------------------------+
 * 0 |     Type      |      Code     |          Checksum             |
 *   +---------------+---------------+-------------------------------+
 * 4 |           Identifier          |        Sequence Number        |
 *   +-------------------------------+-------------------------------+
 */
/* Summary of Message Types {{{1 ---------------------------------------------*/
#define ICMP_MSG_TYPE_ECHO_REPLY                0
#define ICMP_MSG_TYPE_DESTINATION_UNREACHABLE   3
#define ICMP_MSG_TYPE_SOURCE_QUENCH             4
#define ICMP_MSG_TYPE_REDIRECT                  5
#define ICMP_MSG_TYPE_ECHO                      8
#define ICMP_MSG_TYPE_TIME_EXCEEDED            11
#define ICMP_MSG_TYPE_PARAMETER_PROBLEM        12
#define ICMP_MSG_TYPE_TIMESTAMP                13
#define ICMP_MSG_TYPE_TIMESTAMP_REPLY          14
#define ICMP_MSG_TYPE_INFORMATION_REQUEST      15
#define ICMP_MSG_TYPE_INFORMATION_REPLY        16
/* }}}1 */

#endif
