#ifndef _UDP_H_
#define _UDP_H_

#include "services.h"

/*
    0               1               2               3
    1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8 1 2 3 4 5 6 7 8
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 0 |          SOURCE PORT          |       DESTINATION PORT        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 4 |            LENGTH             |       CHECKSUM (OPT)          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/

#define UDP_HEADER_SRC_PORT 0
#define UDP_HEADER_DST_PORT 2
#define UDP_HEADER_LENGTH   4
#define UDP_HEADER_CHK_SUM  6

#define UDP_HEADER_LEN      8

#endif
