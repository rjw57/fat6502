; crc32 code taken from 6502.org
; written by Paul Guertin (pg@sff.net)


	.include "drivecpu.i"


	.export crc_init
	.export crc_reset
	.export crc_update
	.exportzp crc


	.zeropage

crc:	.res 4
xtemp:	.res 1


	.bss

	.align 256
crct0:	.res 256
crct1:	.res 256
crct2:	.res 256
crct3:	.res 256


	.code

crc_init:
	ldx #0		; x counts from 0 to 255
@byteloop:
	lda #0		; a contains the high byte of the crc-32
	sta crc+2	; the other three bytes are in memory
	sta crc+1
	stx crc
	ldy #8		; y counts bits in a byte
@bitloop:
	lsr		; the crc-32 algorithm is similar to crc-16
	ror crc+2	; except that it is reversed (originally for
	ror crc+1	; hardware reasons). this is why we shift
	ror crc		; right instead of left here.
	bcc @noadd	; do nothing if no overflow
	eor #$ed	; else add crc-32 polynomial $edb88320
	pha		; save high byte while we do others
	lda crc+2
	eor #$b8	; most reference books give the crc-32 poly
	sta crc+2	; as $04c11db7. this is actually the same if
	lda crc+1	; you write it in binary and read it right-
	eor #$83	; to-left instead of left-to-right. doing it
	sta crc+1	; this way means we won't have to explicitly
	lda crc		; reverse things afterwards.
	eor #$20
	sta crc
	pla		; restore high byte
@noadd:
	dey
	bne @bitloop	; do next bit
	sta crct3,x	; save crc into table, high to low bytes
	lda crc+2
	sta crct2,x
	lda crc+1
	sta crct1,x
	lda crc
	sta crct0,x
	inx
	bne @byteloop	; do next byte
	rts


crc_reset:
	lda #$ff
	sta crc
	sta crc+1
	sta crc+2
	sta crc+3
	rts


crc_update:
	stx xtemp
	eor crc		; quick crc computation with lookup tables
	tax
	lda crc+1
	eor crct0,x
	sta crc
	lda crc+2
	eor crct1,x
	sta crc+1
	lda crc+3
	eor crct2,x
	sta crc+2
	lda crct3,x
	sta crc+3
	ldx xtemp
	rts
