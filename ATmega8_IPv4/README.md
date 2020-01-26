# ATmega8 IPv4 stack
## Description
This project implements IPv4 stack in an ATmega8 microcontroller, everything written in Assembly.

Features:
* Generates and can reply ARP packes.
* Replies to HTTP requests.
* Replies to ping packets (ICMP).
* It uses DHCP to obtain IPv4 IP address.
* It can send UDP packets to registered IP addresses.
* Reads DHT11 (humidity and temperature) sensor.

Tested at 1, 2, 4 and 8 MHz.

## Compiling
To compile with debugging messages on the UART port:

$ make

To compile without debugging through UART:

$ make DEBUG=0

If using avrdude with USBasp, then firmware can be written to the microcontroller by:

$ make install
