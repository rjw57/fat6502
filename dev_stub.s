	.include "drivecpu.i"

	.exportzp sectorptr
	.export lba
	.export volsector
	.export dev_read_sector
	.export dev_write_sector

dev_init:		jmp (dev_init_vector)
dev_read_sector:	jmp (dev_read_sector_vector)
dev_write_sector:	jmp (dev_write_sector_vector)

	.bss
vectablesize		= 3
vector_table:		.res vectablesize * 2
dev_init_vector		= vector_table
dev_read_sector_vector	= vector_table + 2
dev_write_sector_vector	= vector_table + 4

volsector:		.res 4	; 32-bit LBA start address of active partition
lba:			.res 4	; 32-bit block address

	.zeropage
sectorptr:		.res 2	; pointer to where data is loaded
