; this file acts as an abstraction layer between the device
; drivers and the filesystem code


	.include "drivecpu.i"


	.export dev_init
	.export dev_read_sector
	.export dev_set
	.export lba
	.exportzp sectorptr

	.import ide_init		; ide hard drives
	.import ide_read_sector
	.importzp devtype_hd

	.import atapi_init		; ATAPI drives
	.import atapi_read_sector
	.importzp devtype_cd

	.import floppy_init		; floppy disks
	.import floppy_read_sector
	.importzp devtype_floppy

	.bss

	.align 2
vectablesize		= 2
vector_table:		.res vectablesize * 2
dev_init_vector		= vector_table
dev_read_sector_vector	= vector_table + 2


	.rodata

ide_vectors:
	.word ide_init
	.word ide_read_sector

atapi_vectors:
	.word atapi_init
	.word atapi_read_sector

floppy_vectors:
	.word floppy_init
	.word floppy_read_sector


	.segment "DEVVECTORS"

	; vectors at $ffxx

dev_init:		jmp (dev_init_vector)
dev_read_sector:	jmp (dev_read_sector_vector)
dev_set:		jmp _dev_set
			.res 7


	.segment "DEVBSS"

lba:			.res 4	; 32-bit block address


	.segment "DEVZP", zeropage

sectorptr:		.res 2	; pointer to where data is loaded


	.code

; call with device identifier in A
_dev_set:
	cmp #devtype_hd
	beq @ide
	cmp #devtype_cd
	beq @atapi
	cmp #devtype_floppy
	beq @floppy
	sec
	rts

@ide:
	ldx #0
@copyide:
	lda ide_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyide
	clc
	rts

@atapi:
	ldx #0
@copyatapi:
	lda atapi_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyatapi
	clc
	rts

@floppy:
	ldx #0
@copyfloppy:
	lda floppy_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyfloppy
	clc
	rts
