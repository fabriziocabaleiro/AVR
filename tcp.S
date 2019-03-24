/* vim: set filetype=S foldmethod=marker: */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "tcp.h"
#include "enc28j60.h"
.LIST

.global TCP_HANDLE_PKT

/*******************************************************************************
 * TCP Handle {{{
 * TCP not supported at the moment
 ******************************************************************************/
#if 0
TCP_HANDLE_PKT:
    ret
#endif
/* }}} */
