#ifndef _DHT11_H_
#define _DHT11_H_
#define DHT11_PAYLOAD_LEN  5 /* 40 Bits */

/* Payload offsets */
#define DHT11_DATA_RH_INT  0 /* Relative humidity integer part */
#define DHT11_DATA_RH_FRAC 1 /* Relative humidity fractional part */
#define DHT11_DATA_T_INT   2 /* Temperature integer part */
#define DHT11_DATA_T_FRAC  3 /* Temperature fractional part */
#define DHT11_DATA_CHKSUM  4 /* Checksum */
#endif
