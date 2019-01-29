GCC-OPT=-mmcu=atmega8 -std=gnu99 -g

main.elf: main.S spi.S enc28j60.S defs.h arp.S
	avr-gcc $(GCC-OPT) $< -o $@
	avr-objcopy -O ihex -R .eeprom -R .fuse -R .lock -R .signature $@ main.hex
	avr-size -A main.hex

install:
	/usr/bin/avrdude -c usbasp -p m8 -U flash:w:main.hex
	/usr/bin/avrdude -c usbasp -p m8 -U eeprom:w:eeprom.hex

read:
	/usr/bin/avrdude -c usbasp -p m8 -U flash:r:main2.hex:i

clean:
	rm main.elf
