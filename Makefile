AS = ca65
LD = ld65
CC = cc65
CFLAGS = -Oirs
AFLAGS = #-DDEBUG
CFG = bigboot.cfg
RM = rm -f


%.o:   	%.c
	@$(CC) $(CFLAGS) $<
	@$(AS) -o $@ $(AFLAGS) $(*).s

%.o:	%.s
	@$(AS) -g -o $@ $(AFLAGS) $<


OBJS = \
	main.o \
	vectors.o \
	zeropage.o \
	keyboard.o \
	ide.o \
	floppy.o \
	fat.o \
	iso9660.o \
	boot.o \
	buffers.o \
	debug.o \
	vol.o \
	dev.o \
	controller.o \
	timestamp.o \
	graphics.o \
	version.o

INCS = \
	drivecpu.i \
	ide.i


all: bigboot.bin boot232.bin testkbd.bin

bigboot.bin: $(OBJS) $(INCS)
	$(LD) -C $(CFG) -m bigboot.map -o $@ $(OBJS)

boot232.bin: rs232boot.o rs232boot_reloc.o debug.o buffers.o vectors.o timestamp.o
	$(LD) -C $(CFG) -m boot232.map -o $@ $^

testkbd.bin: testkbd.o debug.o buffers.o vectors.o
	$(LD) -C $(CFG) -m testkbd.map -o $@ $^

.PHONY: timestamp.s
timestamp.s:
	@echo " .export timestamp" > timestamp.s
	@echo " .rodata" >> timestamp.s
	@echo "timestamp:" >> timestamp.s
	@date "+ .byte \"%Y-%m-%d %H:%M:%S %Z\"" >> timestamp.s
	@echo " .byte 0" >> timestamp.s

jeri: bigboot.bin boot232.bin
	cat 0s mrt512.bin bigboot.bin > ../bigboot.bin
	cat 0s mrt512.bin boot232.bin > ../boot232.bin


clean:
	$(RM) $(OBJS) \
		timestamp.s \
		bigboot.bin boot232.bin testkbd.bin \
		rs232boot.o rs232boot_reloc.o \
		bigboot.map boot232.map testkbd.map

distclean: clean
	$(RM) *~
