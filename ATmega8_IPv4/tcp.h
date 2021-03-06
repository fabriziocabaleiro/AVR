/* LICENSE {{{ -----------------------------------------------------------------
 * IPv4 stack for AVR (ATmega8) microcontroller.
 * Copyright (C) 2020 Fabrizio Cabaleiro
 * 
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, version 2.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 * 
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <https://www.gnu.org/licenses/>.
 * ------------------------------------------------------------------------}}}*/
#ifndef _TCP_H_
#define _TCP_H_

#include "services.h"

#define TCP_HEADER_SRC_PORT   0
#define TCP_HEADER_DST_PORT   2
#define TCP_HEADER_SQNC_N     4
#define TCP_HEADER_ACK_N      8
#define TCP_HEADER_DO_FLAGS  12
#define TCP_HEADER_WINDOW    14
#define TCP_HEADER_CHKSUM    16
#define TCP_HEADER_URGENT_P  18
#define TCP_HEADER_OPTIONS   20
//#define TCP_HEADER_PADDING   23
//#define TCP_HEADER_DATA      24

/* Bit location */
#define TCP_HEADER_FLAG_CWR 7 /* Congestion Window Reduced */
#define TCP_HEADER_FLAG_ECE 6 /* ECN Echo */
#define TCP_HEADER_FLAG_URG 5 /* Urgent */
#define TCP_HEADER_FLAG_ACK 4 /* Ack */
#define TCP_HEADER_FLAG_PSH 3 /* Push */
#define TCP_HEADER_FLAG_RST 2 /* Reset */
#define TCP_HEADER_FLAG_SYN 1 /* Syn */
#define TCP_HEADER_FLAG_FIN 0 /* Fin */
/* Bit mask */
#define TCP_HEADER_DO_FLAGS_H_DATA_OFFSET  0xF0
#define TCP_HEADER_DO_FLAGS_H_RSRVD        0x0E
#define TCP_HEADER_DO_FLAGS_H_FLAG_NS      0x01 /* ECN-nonce - concealment protection */
#define TCP_HEADER_DO_FLAGS_H_FLAG_CWR     0x80 /* Congestion Window Reduced */
#define TCP_HEADER_DO_FLAGS_H_FLAG_ECE     0x40 /* ECN Echo */
#define TCP_HEADER_DO_FLAGS_H_FLAG_URG     0x20 /* Urgent */
#define TCP_HEADER_DO_FLAGS_H_FLAG_ACK     0x10 /* Ack */
#define TCP_HEADER_DO_FLAGS_H_FLAG_PSH     0x08 /* Push */
#define TCP_HEADER_DO_FLAGS_H_FLAG_RST     0x04 /* Reset */
#define TCP_HEADER_DO_FLAGS_H_FLAG_SYN     0x02 /* Syn */
#define TCP_HEADER_DO_FLAGS_H_FLAG_FIN     0x01 /* Fin */

/*
 * http://www.networksorcery.com/enp/rfc/rfc2018.txt
      Kind     Length    Meaning
      ----     ------    -------
       0         -       End of option list.
       1         -       No-Operation.
       2         4       Maximum Segment Size.
       3         3       Window scale factor
       4         2       SACK permitted
       8        10       Timestamp
*/
#define TCP_OPT_END      0
#define TCP_OPT_NOP      1
#define TCP_OPT_MSS      2
#define TCP_OPT_MSS_LEN  4
#define TCP_OPT_WSF      3
#define TCP_OPT_WSF_LEN  3
#define TCP_OPT_SACK     4
#define TCP_OPT_SACK_LEN 2
#define TCP_OPT_TTP      8
#define TCP_OPT_TTP_LEN 10
/*
    0               1               2               3
    0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 0 |          Source Port          |       Destination Port        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 4 |                        Sequence Number                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 8 |                    Acknowledgment Number                      |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
12 |  Data |Rsrvd|N|C|E|U|A|P|R|S|F|                               |
   | Offset|0 0 0|S|W|C|R|C|S|S|Y|I|            Window             |
   |       |     | |R|E|G|K|H|T|N|N|                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
16 |           Checksum            |         Urgent Pointer        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
20 |                    Options                    |    Padding    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
24 |                             data                              |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

  Source Port:  16 bits
    The source port number.

  Destination Port:  16 bits
    The destination port number.

  Sequence Number:  32 bits

    The sequence number of the first data octet in this segment (except
    when SYN is present). If SYN is present the sequence number is the
    initial sequence number (ISN) and the first data octet is ISN+1.

  Acknowledgment Number:  32 bits

    If the ACK control bit is set this field contains the value of the
    next sequence number the sender of the segment is expecting to
    receive.  Once a connection is established this is always sent.

  Data Offset:  4 bits

    The number of 32 bit words in the TCP Header.  This indicates where
    the data begins.  The TCP header (even one including options) is an
    integral number of 32 bits long.

  Reserved:  6 bits

    Reserved for future use.  Must be zero.

  Control Bits:  6 bits (from left to right):

    URG:  Urgent Pointer field significant
    ACK:  Acknowledgment field significant
    PSH:  Push Function
    RST:  Reset the connection
    SYN:  Synchronize sequence numbers
    FIN:  No more data from sender

  Window:  16 bits

    The number of data octets beginning with the one indicated in the
    acknowledgment field which the sender of this segment is willing to
    accept.

  Checksum:  16 bits

    The checksum field is the 16 bit one's complement of the one's
    complement sum of all 16 bit words in the header and text.  If a
    segment contains an odd number of header and text octets to be
    checksummed, the last octet is padded on the right with zeros to
    form a 16 bit word for checksum purposes.  The pad is not
    transmitted as part of the segment.  While computing the checksum,
    the checksum field itself is replaced with zeros.

    The checksum also covers a 96 bit pseudo header conceptually
    prefixed to the TCP header.  This pseudo header contains the Source
    Address, the Destination Address, the Protocol, and TCP length.
    This gives the TCP protection against misrouted segments.  This
    information is carried in the Internet Protocol and is transferred
    across the TCP/Network interface in the arguments or results of
    calls by the TCP on the IP.

                     +--------+--------+--------+--------+
                     |           Source Address          |
                     +--------+--------+--------+--------+
                     |         Destination Address       |
                     +--------+--------+--------+--------+
                     |  zero  |  PTCL  |    TCP Length   |
                     +--------+--------+--------+--------+

      The TCP Length is the TCP header length plus the data length in
      octets (this is not an explicitly transmitted quantity, but is
      computed), and it does not count the 12 octets of the pseudo
      header.

  Urgent Pointer:  16 bits

    This field communicates the current value of the urgent pointer as a
    positive offset from the sequence number in this segment.  The
    urgent pointer points to the sequence number of the octet following
    the urgent data.  This field is only be interpreted in segments with
    the URG control bit set.

  Options:  variable

    Options may occupy space at the end of the TCP header and are a
    multiple of 8 bits in length.  All options are included in the
    checksum.  An option may begin on any octet boundary.  There are two
    cases for the format of an option:

      Case 1:  A single octet of option-kind.

      Case 2:  An octet of option-kind, an octet of option-length, and
               the actual option-data octets.

    The option-length counts the two octets of option-kind and
    option-length as well as the option-data octets.

    Note that the list of options may be shorter than the data offset
    field might imply.  The content of the header beyond the
    End-of-Option option must be header padding (i.e., zero).

    A TCP must implement all options.
    Currently defined options include (kind indicated in octal):

      Kind     Length    Meaning
      ----     ------    -------
       0         -       End of option list.
       1         -       No-Operation.
       2         4       Maximum Segment Size.
       3         3       Window scale factor
       8        10       Timestamp


    Specific Option Definitions

      End of Option List

        +--------+
        |00000000|
        +--------+
         Kind=0

        This option code indicates the end of the option list.  This
        might not coincide with the end of the TCP header according to
        the Data Offset field.  This is used at the end of all options,
        not the end of each option, and need only be used if the end of
        the options would not otherwise coincide with the end of the TCP
        header.

      No-Operation

        +--------+
        |00000001|
        +--------+
         Kind=1

        This option code may be used between options, for example, to
        align the beginning of a subsequent option on a word boundary.
        There is no guarantee that senders will use this option, so
        receivers must be prepared to process options even if they do
        not begin on a word boundary.

      Maximum Segment Size

        +--------+--------+---------+--------+
        |00000010|00000100|   max seg size   |
        +--------+--------+---------+--------+
         Kind=2   Length=4

        Maximum Segment Size Option Data:  16 bits

          If this option is present, then it communicates the maximum
          receive segment size at the TCP which sends this segment.
          This field must only be sent in the initial connection request
          (i.e., in segments with the SYN control bit set).  If this
          option is not used, any segment size is allowed.

  Padding:  variable

    The TCP header padding is used to ensure that the TCP header ends
    and data begins on a 32 bit boundary.  The padding is composed of
    zeros.
*/


#endif
