; flash rom device


	.include "drivecpu.i"

	.export rom_init
	.export rom_read_sector
	.export rom_write_sector
	.exportzp devtype_rom

	.import lba
	.importzp sectorptr


	.import debug_put
	.import debug_puts
	.import debug_crlf


	.bss

devtype_rom	= $04

shiftemp:	.res 1
count:		.res 1


	.zeropage

datareg:	.res 1


	.code

; initialize rom drive
rom_init:
	clc
	rts


; read sector
rom_read_sector:
	ldy lba + 1		; set the bank
	lda fa_reg,y
	sta datareg

	jsr fa_clear		; clear flash address

	lda lba			; shift in 8 bits
	sta shiftemp
	ldy #8
@shift:
	jsr fa_shift
	asl shiftemp
	bcc :+
	jsr fa_inc
:	dey
	bne @shift

	ldy #9			; pad with 9 clear bits
:	jsr fa_shift
	dey
	bne :-

	lda #2			; read 2 x 256 bytes
	sta count
	ldy #0
@read:
	ldx #dev_clk2		; load data
	lda datareg
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


fa_clear:
	ldx #dev_clk2
	lda #flash_clear
	sca
	ldx #dev_release
	sca
	rts

fa_inc:
	ldx #dev_clk2
	lda #flash_inc
	sca
	ldx #dev_release
	sca
	rts

fa_shift:
	ldx #dev_clk2
	lda #flash_shift
	sca
	ldx #dev_release
	sca
	rts

fa_data:
	ldx #dev_clk2
	lda datareg
	sca
	ild
	ldx #dev_release
	sca
	rts


; write sector
rom_write_sector:
	sec
	rts


	.rodata

fa_reg:
	.byte <flash_data
	.byte <flash_data + 1
	.byte <flash_data + 2
	.byte <flash_data + 3
