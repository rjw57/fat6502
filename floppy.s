	.include "drivecpu.i"

	.export floppy_init
	.export floppy_read_sector
	.exportzp devtype_floppy


devtype_floppy	= $03


	.code

floppy_init:
floppy_read_sector:
	sec
	rts
