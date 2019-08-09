/* vim: set filetype=S foldmethod=marker: */
/* INCLUDES {{{1 */
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "tcp.h"
#include "enc28j60.h"
.LIST

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global TCP_HANDLE_PKT

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* TCP Handle {{{2 -------------------------------------------------------------
 * TCP not supported at the moment */
#if 0
TCP_HANDLE_PKT:
    ret
#endif

.end
