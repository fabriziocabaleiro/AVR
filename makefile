GCC-OPT=-mmcu=atmega8 -std=gnu99 -g -Wall
OBJS=main.o spi.o enc28j60.o arp.o ipv4.o dht11.o eeprom.o udp.o comm.o adc.o dhcp.o tcp.o icmp.o eeprom_data.o

main.elf: ${OBJS}
	avr-gcc ${GCC-OPT} $^ -o $@
	avr-objcopy -O ihex -R .eeprom -R .fuse -R .lock -R .signature $@ main.hex
	@echo Sizes:
	@avr-size -B main.hex
	@avr-size -B ${OBJS} | sed 1d | sort -n -r

# TODO: fix dependency on header file
%.o: %.S defs.h
	avr-gcc ${GCC-OPT} -c -o $@ $<

install:
	/usr/bin/avrdude -c usbasp -p m8 -U flash:w:main.hex
	/usr/bin/avrdude -c usbasp -p m8 -U eeprom:w:eeprom_data.hex

eeprom:
	/usr/bin/avrdude -c usbasp -p m8 -U eeprom:r:eeprom_out.hex:i
	cat eeprom_out.hex

eeprom_data.o: eeprom_data.S
	avr-gcc $< -c -o eeprom_data.elf
	avr-gcc ${GCC-OPT} -c -o $@ $< 
	avr-objcopy -O ihex eeprom_data.elf eeprom_data.hex


read:
	/usr/bin/avrdude -c usbasp -p m8 -U flash:r:main2.hex:i

clean:
	rm ${OBJS} main.elf
