################################################################################
#                          ATmega8 + ENC28J60 + DHT11                          #
################################################################################
DEBUG  ?= 1
TARGET ?= main
DEPDIR  = Deps
OBJDIR  = Objs
GCCOPT  = -mmcu=atmega8 -std=gnu99 -g -Wall
CLOCK  ?= 1M
WRITE_EEPROM = @\#

ifeq (${CLOCK}, 1M)
    LFUSE_BINARY_OR = 0x01
    F_CPU           = 1000000
else ifeq (${CLOCK}, 2M)
    LFUSE_BINARY_OR = 0x02
    F_CPU           = 2000000
else ifeq (${CLOCK}, 4M)
    LFUSE_BINARY_OR = 0x03
    F_CPU           = 4000000
else ifeq (${CLOCK}, 8M)
    LFUSE_BINARY_OR = 0x04
    F_CPU           = 8000000
else
    $(error Unsupported clock frequency)
endif

ifeq (${TARGET}, main)
    WRITE_EEPROM = 
    OBJS = main.o          \
           eeprom.o        \
           spi.o           \
           timer.o         \
           dht11.o         \
           adc.o           \
           enc28j60.o      \
           arp.o           \
           ipv4.o          \
           udp.o           \
           dhcp.o          \
           tcp.o           \
           icmp.o          \
           division.o      \
           utils.o         \
           http.o          \
           comm.o
else ifeq (${TARGET}, adc)
    OBJS = main_adc.o      \
           timer.o         \
           adc.o
else
    $(error Unknown target)
endif

ifeq (${DEBUG}, 1)
    GCCOPT += -DUSE_UART
    OBJS   += uart.o strings.o
else
    GCCOPT += -DNDEBUG
endif

# GCC flags for dependencies auto generation
DEPOPTS = -MP -MD -MF ${DEPDIR}/$(notdir $@).d

${TARGET}.elf: $(addprefix ${OBJDIR}/, ${OBJS})
	avr-gcc ${GCCOPT} $^ -o $@
	./post_checks.sh ${TARGET}
	avr-objcopy -O ihex -R .data -R .eeprom -R .fuse -R .lock -R .signature $@ ${TARGET}.hex
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
	avrdude -c usbasp -p m8 -U flash:w:${TARGET}.hex
	${WRITE_EEPROM}avrdude -c usbasp -p m8 -U eeprom:w:eeprom_data.hex

read:
	avrdude -c usbasp -p m8 -U flash:r:main_out.hex:i

# EEPROM read
eread:
	avrdude -c usbasp -p m8 -U eeprom:r:eeprom_out.hex:i
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

.PHONY: set-clock
set-clock:
	$(eval LFUSE=$(shell avrdude -c usbasp -p m8 -U lfuse:r:/dev/stdout:h))
	echo Current LFUSE ${LFUSE}
	$(eval NLFUSE=$(shell printf "0x%x" $$((${LFUSE} & 0xF0 | ${LFUSE_BINARY_OR}))))
	echo New LFUSE ${NLFUSE}
	sed -i 's/#define F_CPU [0-9]\+\(.*\)/#define F_CPU ${F_CPU}\1/' defs.h
	avrdude -c usbasp -p m8 -U lfuse:w:${NLFUSE}:m

clean:
	test -d ${DEPDIR} && rm -r ${DEPDIR}
	test -d ${OBJDIR} && rm -r ${OBJDIR}
	rm *.elf *.hex eeprom_data.h cscope* tags

# Generate directory if doesn't exists
${OBJDIR} ${DEPDIR}:
	test -d $@ || mkdir $@

# Include automatic dependencies
-include $(wildcard ${DEPDIR}/*)
