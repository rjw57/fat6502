	.include "drivecpu.i"

	.export support_core_load

	.import flash_addr_clear
	.import flash_addr_inc
	.import flash_addr_shift
	.import flash_data_read
	.import flash_reg_tab
	.importzp flash_reg


	.zeropage

lastbyte:	.res 1


	.code

support_core_load:
	; set address to $10000
	jsr flash_addr_clear	; 0
	jsr flash_addr_inc	; 1
	ldy #16
:	jsr flash_addr_shift	; 16 x 0s
	dey
	bne :-

	; set bank 3 (6-70000)
	;ldy #3			; moved into rle_read
	;lda flash_reg_tab,y
	;sta flash_reg

	; read rle compressed core data
	jsr rle_read		; read the first byte
	sta lastbyte		; save as last byte
	saf			; store
@unpack:
	jsr rle_read		; read next byte
	cmp lastbyte		; same as last one?
	beq @rle		; yes, unpack
	sta lastbyte		; save as last byte
	saf			; store
	jmp @unpack		; next
@rle:
	jsr rle_read		; read byte count
	tay
	beq @end		; 0 = end of stream
	lda lastbyte
@read:
	saf			; store X bytes
	dey
	bne @read
	beq @unpack		; next
@end:
	clc
	rts


rle_read:
	ldx #dev_clk2		; read byte
	lda #<flash_data + 3
	sca
	ild
	pha
	ldx #dev_release
	sca

	ldx #dev_clk2		; inc address
	lda #flash_inc
	sca
	ldx #dev_release
	sca
	pla
	rts
