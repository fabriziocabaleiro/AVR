################################################################################
#                          ATmega8 + ENC28J60 + DHT11                          #
################################################################################
DEBUG = 0
OBJS = main.o         \
       eeprom.o       \
       spi.o          \
       timer.o        \
       dht11.o        \
       adc.o          \
       enc28j60.o     \
       arp.o          \
       ipv4.o         \
       udp.o          \
       dhcp.o         \
       tcp.o          \
       icmp.o         \
       division.o     \
       utils.o        \
       http.o         \
       comm.o

DEPDIR = Deps
OBJDIR = Objs
GCCOPT = -mmcu=atmega8 -std=gnu99 -g -Wall

ifeq (${DEBUG}, 1)
    GCCOPT += -DUSE_UART
    OBJS   += uart.o strings.o
else
    GCCOPT += -DNDEBUG
endif

# GCC flags for dependencies auto generation
DEPOPTS = -MP -MD -MF ${DEPDIR}/$(notdir $@).d

main.elf: $(addprefix ${OBJDIR}/, ${OBJS})
	avr-gcc ${GCCOPT} $^ -o $@
	./post_checks.sh
	avr-objcopy -O ihex -R .data -R .eeprom -R .fuse -R .lock -R .signature $@ main.hex
	@echo Sizes:
	@avr-size -B $@
	@avr-size -B eeprom_data.elf $(addprefix ${OBJDIR}/, ${OBJS}) | sed 1d | sort -n -r
	@# Update cscope and ctags database
	$(eval FILES := $(shell sed -n '/:$$/s/:$$//p' ${DEPDIR}/* | sort -u) \
		${OBJS:.o=.S} eeprom_data.S)
	@cscope -k -b -q ${FILES}
	@ctags ${FILES}

# Implicit rules with pattern rules
# On the first go, without dependencies in ./${DEPDIR}, this implicit rule will apply
# and dependency file will be generated.
${OBJDIR}/%.o: %.S makefile | eeprom_data.h ${DEPDIR} ${OBJDIR}
	avr-gcc ${DEPOPTS} ${GCCOPT} -c -o $@ $<

install:
	/usr/bin/avrdude -c usbasp -p m8 -U flash:w:main.hex
	/usr/bin/avrdude -c usbasp -p m8 -U eeprom:w:eeprom_data.hex

read:
	/usr/bin/avrdude -c usbasp -p m8 -U flash:r:main_out.hex:i

# EEPROM read
eread:
	/usr/bin/avrdude -c usbasp -p m8 -U eeprom:r:eeprom_out.hex:i
	cat eeprom_out.hex

eeprom_data.hex eeprom_data.h: eeprom_data.S
	avr-gcc $< -c -o eeprom_data.elf
	avr-objcopy -O ihex eeprom_data.elf eeprom_data.hex
	avr-nm --no-sort -B eeprom_data.elf | awk 'BEGIN {                     \
		printf "#ifndef _EEPROM_DATA_H_\n";                            \
		printf "#define _EEPROM_DATA_H_\n\n";                          \
		printf "/* Auto generated, based on eeprom_data.S */\n\n"      \
		} {                                                            \
		printf "#define %-40s 0x%04X\n", $$3, strtonum("0x"$$1);         \
		} END {                                                        \
			printf "\n#endif\n";                                   \
		} ' > eeprom_data.h

clean:
	test -d ${DEPDIR} && rm -r ${DEPDIR}
	test -d ${OBJDIR} && rm -r ${OBJDIR}
	rm *.elf *.hex eeprom_data.h cscope* tags

# Generate directory if doesn't exists
${OBJDIR} ${DEPDIR}:
	test -d $@ || mkdir $@

# Include automatic dependencies
-include $(wildcard ${DEPDIR}/*)
