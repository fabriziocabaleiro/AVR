# ATmega8 over IP
## Description
In this project an ATmega8 connects to Internet using an ENC28J60, all the firmware was written in Assembly.

Features:
* Generates and replies to ARP packes.
* Replies to HTTP requests.
* Replies to ping packets (ICMP).
* It uses DHCP to obtain IPv4 IP address.
* It can send UDP packets to registered IP addresses.
* Reads DHT11 (humidity and temperature) sensor.
* Talks over UART for debugging purposes, Baud rate 4800
* Uses the EEPROM to read configuration from and to store the dynamic IP address.

Tested at 1, 2, 4 and 8 MHz.

## Compiling
To compile with debugging messages on the UART port:

$ make

To compile without debugging through UART:

$ make DEBUG=0

If using avrdude with USBasp, then firmware can be written to the microcontroller by:

$ make install

## Clock frequency

To change the clock frequency:

$ make set-clock CLOCK=<freq>
$ make
$ make install

Where freq is 1M, 2M, 4M or 8M.

The target "set-clock" will change the lfuse on the microcontroller and also update the macro F\_CPU defined in defs.h.

## Cscope and Ctags
Cscope and Ctags databases are generated during make. The list of input files used to create those databases is the combination of the assembly files plus all their dependencies (auto-generated files located in Deps folder).

## GCC automatic prerequisites
Prerequisites are stored in Deps (-MF ${DEPDIR}/$(notdir $@).d). Using -MP will add a phony target for each dependency other than the main file, this is handy to extract the list of dependency files.

For more detailed explanation:
* https://www.gnu.org/software/make/manual/html_node/Automatic-Prerequisites.html
* http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
