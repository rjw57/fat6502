; this file acts as an abstraction layer between the device
; drivers and the filesystem code


	.include "drivecpu.i"


	.export dev_init
	.export dev_read_sector
	.export dev_write_sector
	.export dev_set
	.export dev_find_volume
	.export lba
	.export devtype
	.export volsector
	.exportzp sectorptr

	.import clusterbuf
	.importzp ptr

	.import ide_init		; ide hard drives
	.import ide_read_sector
	.import ide_write_sector
	.importzp devtype_hd

	.import atapi_init		; ATAPI drives
	.import atapi_read_sector
	.import atapi_write_sector
	.importzp devtype_cd

	.import floppy_init		; floppy disks
	.import floppy_read_sector
	.import floppy_write_sector
	.importzp devtype_floppy

	.import rom_init		; rom disks
	.import rom_read_sector
	.import rom_write_sector
	.importzp devtype_rom


	.bss

volsector:		.res 4	; 32-bit LBA start address of active partition


	.align 2
vectablesize		= 3
vector_table:		.res vectablesize * 2
dev_init_vector		= vector_table
dev_read_sector_vector	= vector_table + 2
dev_write_sector_vector	= vector_table + 4


	.rodata

ide_vectors:
	.word ide_init
	.word ide_read_sector
	.word ide_write_sector

atapi_vectors:
	.word atapi_init
	.word atapi_read_sector
	.word atapi_write_sector

floppy_vectors:
	.word floppy_init
	.word floppy_read_sector
	.word floppy_write_sector

rom_vectors:
	.word rom_init
	.word rom_read_sector
	.word rom_write_sector


	.segment "DEVVECTORS"

	; vectors at $ffxx

dev_init:		jmp (dev_init_vector)
dev_read_sector:	jmp (dev_read_sector_vector)
dev_set:		jmp _dev_set
dev_find_volume:	jmp _dev_find_volume
dev_write_sector:	jmp (dev_write_sector_vector)
			.res 1


	.segment "DEVBSS"

lba:			.res 4	; 32-bit block address
devtype:		.res 1	; current device type


	.segment "DEVZP" : zeropage

sectorptr:		.res 2	; pointer to where data is loaded


	.code

; call with device identifier in A
_dev_set:
	sta devtype
	cmp #devtype_hd
	beq @ide
	cmp #devtype_cd
	beq @atapi
	cmp #devtype_floppy
	beq @floppy
	cmp #devtype_rom
	beq @rom
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

@rom:
	ldx #0
@copyrom:
	lda rom_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyrom
	clc
	rts


; find the first volume on a device and return the filesystem type
_dev_find_volume:
	lda devtype
	cmp #devtype_hd
	beq @ide
	cmp #devtype_cd
	beq @atapi
	cmp #devtype_floppy
	beq @floppy
	cmp #devtype_rom
	beq @rom
@error:
	sec
	rts

@atapi:
	lda #16			; hardcoding is fun
	sta volsector
	lda #0
	sta volsector+1
	sta volsector+2
	sta volsector+3
	lda #$96
	clc
	rts

@floppy:
	jsr readsector0		; if sector 0 is a fat sector
	bcs @error
	lda #0
	ldx #3
:	sta volsector,x
	dex
	bpl :-
	lda #$12		; then it's a FAT12 floppy
	clc
	rts

@rom:
	lda #0			; hardcoding is fun
	sta volsector
	sta volsector+1
	sta volsector+2
	sta volsector+3
	lda #$01		; romfs
	clc
	rts


@ide:
	jsr readsector0
	bcs @error

	ldax #clusterbuf + 446	; pointer to partition table
	stax ptr		; sector must be page aligned...

	ldy #4
@checktype:
	lda (ptr),y		; check file system type
	cmp #$01
	beq @foundfat12		; fat12 uses $01
	cmp #$04		; fat16 uses $04, $06, or $0e
	beq @foundfat16
	cmp #$06
	beq @foundfat16
	cmp #$0e
	beq @foundfat16
	cmp #$0b		; fat32 uses $0b or $0c
	beq @foundfat32
	cmp #$0c
	beq @foundfat32

	lda ptr			; ...or this'll fail
	clc
	adc #16
	sta ptr
	bcc @checktype
	jmp @error		; no partition found

@foundfat12:
	ldx #$12
	.byte $2c
@foundfat16:
	ldx #$16
	.byte $2c
@foundfat32:
	ldx #$32

	ldy #8			; copy volume start sector
:	lda (ptr),y
	sta volsector-8,y
	iny
	cpy #12
	bne :-

	txa			; happy camper
	clc
	rts


readsector0:
	ldx #3
	lda #0
:	sta lba,x
	dex
	bpl :-
	ldax #clusterbuf	; load data into clusterbuf
	stax sectorptr
	jsr dev_read_sector	; read sector 0
	bcc @check
@error:
	sec
	rts
@check:
	lda clusterbuf + $1fe
	cmp #$55
	bne @error

	lda clusterbuf + $1ff
	cmp #$aa
	bne @error

	clc
	rts
