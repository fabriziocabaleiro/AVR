################################################################################
#                             ATmega16 Jtag1 test                              #
################################################################################
OBJS = main.o

DEPDIR = Deps
OBJDIR = Objs
GCCOPT = -mmcu=atmega16a -std=gnu99 -g -Wall

# GCC flags for dependencies auto generation
DEPOPTS = -MP -MD -MF ${DEPDIR}/$(notdir $@).d 

main.elf: $(addprefix ${OBJDIR}/, ${OBJS})
	avr-gcc ${GCCOPT} $^ -o $@
	avr-objcopy -O ihex -R .data -R .eeprom -R .fuse -R .lock -R .signature $@ main.hex
	@echo Sizes:
	@avr-size -B $@

# Implicit rules with pattern rules
# On the first go, without dependencies in ./${DEPDIR}, this implicit rule will apply
# and dependency file will be generated.
${OBJDIR}/%.o: %.S | ${DEPDIR} ${OBJDIR}
	avr-gcc ${DEPOPTS} ${GCCOPT} -c -o $@ $<

install:
	avrdude -c jtag1 -p m16 -U flash:w:main.hex

gdb:
	avarice -B 125000 -j /dev/ttyUSB0 -P atmega16 :6666

gdb-attach:
	avr-gdb -ex "file main.elf" -ex "target remote :6666"

clean:
	test -d ${DEPDIR} && rm -r ${DEPDIR} || true
	test -d ${OBJDIR} && rm -r ${OBJDIR} || true
	test -f main.elf && rm main.elf || true
	test -f main.hex && rm main.hex || true

# Generate directory if doesn't exists
${OBJDIR} ${DEPDIR}:
	test -d $@ || mkdir $@

# Include automatic dependencies
-include $(wildcard ${DEPDIR}/*)
