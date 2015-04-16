# If CC65_DIR is set, add ${CC65_DIR}/bin to path
ifdef CC65_DIR
	export PATH := ${CC65_DIR}/bin:$(PATH)
endif

# Find the cl65 tool if not specified
CL65?=$(shell PATH="$(PATH)" which cl65)
ifeq ($(CL65),)
$(error The cl65 tool was not found. Try setting the CC65_DIR variable.)
endif

LINK_CONFIG := buri.cfg

ASM_INCS:= \
	drivecpu.i \
	ide.i

ASM_SOURCES:= \
	dev_stub.s \
	vol_stub.s \
	buffers.s \
	fat.s

#	vectors.s \
#	zeropage.s \
#	keyboard.s \
#	ide.s \
#	floppy.s \
#	rom.s \
#	flash.s \
#	romfs.s \
#	buffers.s \
#	debug.s \
#	dev.s \
#	controller.s \
#	graphics.s \
#	version.s \
#	bootmenu.s \
#	progressbar.s \
#	checksum.s \
#	alternaterom.s \
#	dsk.s \
#	supportcore.s \
#	risc.s

#	vol.s \
#	boot.s \
#	main.s \
#	iso9660.s \
#	relocate.s \

ASM_BINS:= testdir.bin
ASM_BIN_OBJECTS:=$(ASM_BINS:.bin=.o)
CLEAN_FILES+=$(ASM_BIN_OBJECTS)

ASM_OBJECTS:=$(ASM_SOURCES:.s=.o)
CLEAN_FILES+=$(ASM_OBJECTS)

EXE_FILES=$(ASM_BINS)
CLEAN_FILES+=$(EXE_FILES)

## cl65 command-line flags

# Use the more modern 65C02
CL65_FLAGS+=--cpu 65C02

# Use optimisation
CL65_FLAGS+=-O

# We are using the "none" target for asm
CL65_ASM_FLAGS+=-t none

# We are using the "buri" target for C
CL65_C_FLAGS+=-t buri

# Append linker config configuration to cl65 command line
CL65_FLAGS+=-C "$(LINK_CONFIG)"

.PHONY:all
all: $(EXE_FILES)

.PHONY: clean
clean:
	rm -f $(CLEAN_FILES)

$(ASM_BINS):%.bin: %.o $(LINK_CONFIG) $(ASM_OBJECTS)
	$(CL65) $(CL65_FLAGS) $(CL65_ASM_FLAGS) -o "$@" "$<" $(ASM_OBJECTS)

$(ASM_BIN_OBJECTS) $(ASM_OBJECTS):%.o: %.s $(LINK_CONFIG) $(ASM_INCS)
	$(CL65) $(CL65_FLAGS) $(CL65_ASM_FLAGS) -c -o "$@" "$<"

