/* INCLUDES {{{1 -------------------------------------------------------------*/
.NOLIST
#include <avr/io.h>
#include "defs.h"
#include "tcp.h"
#include "enc28j60.h"
#include "eeprom_data.h"
#include "ipv4.h"
#include "dht11.h"
#include "macros.S"
.LIST

/* MACORS {{{1 ---------------------------------------------------------------*/
#define SEQ_N_LEN            4
#define TCP_PAYLOAD_LEN      (EEPROM_HTTP_RESPONSE_END - EEPROM_HTTP_RESPONSE)

/* GLOBAL {{{1 ---------------------------------------------------------------*/
.global TCP_HANDLE_PKT

/* DATA  {{{1 ----------------------------------------------------------------*/
.section .data
SRAM_TCP_HEADER:
SRAM_TCP_SRC_PORT: .skip 2
SRAM_TCP_DST_PORT: .skip 2
SRAM_TCP_SEQ_N:    .skip 4
SRAM_TCP_ACK_N:    .skip 4
SRAM_TCP_DO_FLAGS: .skip 2
SRAM_TCP_WINDOW:   .skip 2
SRAM_TCP_CHKSUM:   .skip 2
SRAM_TCP_URGENT_P: .skip 2
SRAM_TCP_OPTS:     .skip 40
SRAM_TCP_PAYLOAD:  .skip TCP_PAYLOAD_LEN

/* TEXT {{{1 -----------------------------------------------------------------*/
.section .text

/* TCP_HANDLE_PKT {{{2 ---------------------------------------------------------
 * Handle TCP packet.
 * ---------------------------------------------------------------------------*/
TCP_HANDLE_PKT:
    push  s1 /* TCP header length */
    rcall ETH_READ_BUFFER_START

    /* Read TCP header until beginning of options */
    ldi   zl, lo8(SRAM_TCP_HEADER)
    ldi   zh, hi8(SRAM_TCP_HEADER)
    ldi   a1, TCP_HEADER_OPTIONS
    rcall MEMCPY_SPI_SRAM

    /* Get the TCP header length in bytes */
    /* Load (Data Offset|Flags). Swap and remove Flags */
    lds   a1, SRAM_TCP_DO_FLAGS
    swap  a1
    andi  a1, 0x0F
    /* data offset from words to bytes (*4) */
    lsl   a1
    lsl   a1
    mov   s1, a1 /* TCP header length */

    /* Read the TCP options, remove constant TCP header length */
    subi  a1, TCP_HEADER_OPTIONS
    rcall MEMCPY_SPI_SRAM

    /* Common modification from incoming packet to outgoing packet */
    /* Swap Src/Dst ports */
    ldi   zl, lo8(SRAM_TCP_SRC_PORT)
    ldi   zh, hi8(SRAM_TCP_SRC_PORT)
    ldi   xl, lo8(SRAM_TCP_DST_PORT)
    ldi   xh, hi8(SRAM_TCP_DST_PORT)
    ldi   a1, IPV4_PORT_LEN
    rcall MEMSWAP

    /* Handle sequence number and acknowledge number */
    /* Swap sequence number with acknowledge number */
    /* x was left pointing to Seq. Num. */
    /* z was left pointing to Dst port */
    adiw  zl, TCP_HEADER_ACK_N - TCP_HEADER_DST_PORT
    ldi   a1, 4
    rcall MEMSWAP

    /* Increment acknowledge number by:
     *   1 if SYN or FIN packet.
     *   TCP Payload */
    /* z was left pointing to SRAM_TCP_DO_FLAGS */
    ldd   t1, z + 1 /* Load 2nd byte of SRAM_TCP_DO_FLAGS */
    clr   t2
    andi  t1, (1 << TCP_HEADER_FLAG_SYN | 1 << TCP_HEADER_FLAG_FIN)
    breq  0f
    inc   t2
    /* TODO: add support for 16b payload size */
0:  ldd   a1, y + IPV4_PAYLOAD_LENGTH_IN_BYTES + 1
    sub   a1, s1 /* TCP header length */
    add   a1, t2
    /* x is pointing to SRAM_TCP_ACK_N from previous MEMSWAP */
    rcall ADD_UINT32_BIG_ENDIAN

    /* Set checksum to zero */
    std   z + TCP_HEADER_CHKSUM - TCP_HEADER_DO_FLAGS + 0, zero
    std   z + TCP_HEADER_CHKSUM - TCP_HEADER_DO_FLAGS + 1, zero

    /* Process options */
    adiw  zl, TCP_HEADER_OPTIONS - TCP_HEADER_DO_FLAGS /* set Z to TCP Opts */
    /* The rest of the TCP header is (Data offset * 4 - 20)
     * If we take zl that points to the beginning of the options and add it
     * (data offset - 5) * 4, we will know when zl is at the beginning of the
     * data */
    mov   t2, s1 /* TCP header length */
    subi  t2, 20
    add   t2, zl /* t2 == zl => First byte of data */
    /* Check if zl >= t2, simple comparison based on post-compile check
     * PCC0001 */
0:  cp    t2, zl
    brsh  0f /* Stop processing options as z beyond option's boundary */
    ld    t1, z+
    /* Test end of options */
    cpi   t1, TCP_OPT_END
    breq  0f
    /* Test padding */
    cpi   t1, TCP_OPT_NOP
    breq  0b /* Next option */
    /* Test MSS */
    cpi   t1, TCP_OPT_MSS
    brne  1f
    adiw  zl, TCP_OPT_MSS_LEN - 1
    rjmp  0b /* Next option */
    /* Test WSF */
1:  cpi   t1, TCP_OPT_WSF
    brne  1f
    adiw  zl, TCP_OPT_WSF_LEN - 1
    rjmp  0b /* Next option */
    /* Sack permitted */
1:  cpi   t1, TCP_OPT_SACK
    brne  1f
    adiw  zl, TCP_OPT_SACK_LEN - 1
    rjmp  0b /* Next option */
    /* Test time stamp */
1:  cpi   t1, TCP_OPT_TTP
    brne  1f
    /* Copy original time stamp to reply time stamp */
    adiw  zl, 1
    movw  xl, zl
    adiw  zl, 4
    ldi   a1, 4
    rcall MEMCPY_SRAM_SRAM
    rjmp  0b /* Next option */
1:  DEBUG(PRINT_STR STR_TCP_OPTION_ERR)
0:  ETH_READ_BUFFER_END

    /* Set z to TCP header */
    ldi   zl, lo8(SRAM_TCP_HEADER)
    ldi   zh, hi8(SRAM_TCP_HEADER)

    /* Check if SYN packet */
    ldd   t1, z + (TCP_HEADER_DO_FLAGS + 1)
    andi  t1, (1 << TCP_HEADER_FLAG_SYN | 1 << TCP_HEADER_FLAG_FIN)
    breq  0f

    /* Handle SYN/FIN */
    ldd   t1, z + (TCP_HEADER_DO_FLAGS + 1)
    ori   t1, TCP_HEADER_DO_FLAGS_H_FLAG_ACK
    std   z + (TCP_HEADER_DO_FLAGS + 1), t1
    clr   a4 /* TCP Payload length */
    rjmp  1f

    /* Not SYN/FIN, then move z to beginning of TCP payload */
0:  add   zl, s1 /* TCP header length */
    adc   zh, zero
    /* Call Handle if TCP packet has payload */
    ldd   t1, y + IPV4_PAYLOAD_LENGTH_IN_BYTES + 1
    sub   t1, s1 /* TCP header length */
    breq  9f /* exit */

    /* TCP_PAYLOAD_HANDLE returns the size of the payload */
    rcall HTTP_HANDLE_PKT

    /* Calculate checksums and lengths and write packets to ENC28J60 */
    /* Calculate TCP header + TCP payload */
1:  add   s1, a4
    /* TCP checksum, include Pseudo header */
    ldi   zl, lo8(SRAM_TCP_HEADER)
    ldi   zh, hi8(SRAM_TCP_HEADER)
    mov   a1, s1 /* TCP header + payload */
    ldi   a2, INTERNET_PROTOCOL_NUMBER_TCP
    rcall INTERNET_CHECKSUM_RFC1071
    std   z + (TCP_HEADER_CHKSUM + 0), a3
    std   z + (TCP_HEADER_CHKSUM + 1), a4

    /* Ethernet header */
    rcall ETH_WRITE_BUFFER_PACKET_HEADER

    /* IPv4 header */
    /* IPv4 payload length */
    ldd   a1, y + IPV4_IHL_IN_BYTES
    add   a1, s1 /* + TCP header and payload */
    rcall IPV4_PREPARE_INCOMING_HEADER_FOR_RESPONSE

    /* Write IPv4 header into ENC buffer */
    ldd   a1, y + IPV4_IHL_IN_BYTES
    rcall ETH_WRITE_TO_TRANSMIT_BUFFER

    /* Write TCP header + payload into ENC buffer */
    ldi   zl, lo8(SRAM_TCP_HEADER)
    ldi   zh, hi8(SRAM_TCP_HEADER)
    mov   a1, s1 /* TCP header + payload */
    rcall ETH_WRITE_TO_TRANSMIT_BUFFER
    rcall ETH_WRITE_BUFFER_PACKET_PAYLOAD_FINISH

9:  pop   s1 /* TCP header length */
    ret

.end
