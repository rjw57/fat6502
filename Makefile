AS = ca65
LD = ld65 -vm
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
	version.o \
	bootmenu.o \
	progressbar.o \
	rs232boot_reloc.o \
	init232boot.o \
	relocate.o \
	crc32.o \
	checksum.o \
	alternaterom.o \
	dsk.o

INCS = \
	drivecpu.i \
	ide.i


all: bigboot.bin boot232.bin bootflash.bin testcpc.bin

bigboot.bin: $(OBJS) $(INCS)
	$(LD) -C $(CFG) -m bigboot.map -o $@ $(OBJS)

boot232.bin: rs232boot.o rs232boot_reloc.o init232boot.o relocate.o debug.o buffers.o vectors.o version.o timestamp.o checksum.o
	$(LD) -C $(CFG) -m boot232.map -o $@ $^

bootflash.bin: bootflash.o graphics.o debug.o buffers.o vectors.o version.o timestamp.o checksum.o
	$(LD) -C $(CFG) -m bootflash.map -o $@ $^

testcpc.bin: testcpc.o debug.o buffers.o vectors.o version.o checksum.o
	$(LD) -C $(CFG) -m testcpc.map -o $@ $^

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
	$(RM) *.o \
		timestamp.s \
		rs232boot.o rs232boot_reloc.o \
		bigboot.bin bigboot.map \
		boot232.bin boot232.map \
		bootflash.bin testflash.map \
		testcpc.bin testcpc.map \

distclean: clean
	$(RM) *~
	$(RM) homepage/*~
