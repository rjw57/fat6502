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
	version.o

INCS = \
	drivecpu.i \
	ide.i


all: bigboot.bin boot232.bin

bigboot.bin: $(OBJS) $(INCS)
	$(LD) -C $(CFG) -m bigboot.map -o $@ $(OBJS)

boot232.bin: rs232boot.o rs232boot_reloc.o debug.o buffers.o vectors.o version.o
	$(LD) -C $(CFG) -m boot232.map -o $@ $^

.PHONY: version.s
version.s:
	@echo ".export timestamp" > version.s
	@echo "timestamp:" >> version.s
	@date "+ .byte \"%Y-%m-%d %H:%M:%S %Z\"" >> version.s
	@echo " .byte 0" >> version.s

clean:
	$(RM) $(OBJS) bigboot.bin test232.o debug.o test232.bin scan.o scan.bin

distclean: clean
	$(RM) *~
