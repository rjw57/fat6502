; flash rom device


	.include "drivecpu.i"

	.export rom_init
	.export rom_read_sector
	.export rom_write_sector
	.exportzp devtype_rom

	.import lba
	.importzp sectorptr

	.import flash_addr_clear
	.import flash_addr_inc
	.import flash_addr_shift
	.import flash_data_read
	.import flash_reg_tab
	.importzp flash_reg


	.bss

devtype_rom	= $04

shiftemp:	.res 1
count:		.res 1


	.code

; initialize rom drive
rom_init:
	clc
	rts


; read sector
rom_read_sector:
	ldy lba + 1		; set the bank
	lda flash_reg_tab,y
	sta flash_reg

	jsr flash_addr_clear		; clear flash address

	lda lba			; shift in 8 bits
	sta shiftemp
	ldy #8
@shift:
	jsr flash_addr_shift
	asl shiftemp
	bcc :+
	jsr flash_addr_inc
:	dey
	bne @shift

	ldy #9			; pad with 9 clear bits
:	jsr flash_addr_shift
	dey
	bne :-

	lda #2			; read 2 x 256 bytes
	sta count
	ldy #0
@read:
	ldx #dev_clk2		; load data
	lda flash_reg
	sca
	ild
	ldx #dev_release	; <- can I remove
	sca			; <- these two?

	sta (sectorptr),y	; store

	ldx #dev_clk2		; inc addr
	lda #flash_inc
	sca
	ldx #dev_release	; <- and these
	sca 			; <- here?

	iny
	bne @read

	inc sectorptr + 1	; next page
	dec count
	bne @read

	clc
	rts


; write sector
rom_write_sector:
	sec
	rts
