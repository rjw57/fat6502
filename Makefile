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
	controller.o

INCS = \
	drivecpu.i \
	ide.i


all: bigboot.bin scan.bin

bigboot.bin: $(OBJS) $(INCS)
	$(LD) -C $(CFG) -m bigboot.map -o $@ $(OBJS)

test232.bin: test232.o debug.o buffers.o vectors.o
	$(LD) -C $(CFG) -m test232.map -o $@ $^

scan.bin: scan.o debug.o buffers.o vectors.o ide.o dev.o floppy.o
	$(LD) -C $(CFG) -m scan.map -o $@ $^

clean:
	$(RM) $(OBJS) bigboot.bin test232.o debug.o test232.bin scan.o scan.bin

distclean: clean
	$(RM) *~
