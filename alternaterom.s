	.include "drivecpu.i"

	.export checkaltrom

	.importzp ptr

	.import warmstartvector

	.import clusterbuf


	.zeropage

crc:	.res 4
crct0	= clusterbuf
crct1	= clusterbuf + $100
crct2	= clusterbuf + $200
crct3	= clusterbuf + $300


	.segment "RELOC"

orgcrc:		.res 4
ctr:		.res 1

rombank		= 2


checkaltrom:
	jsr setrombank5

	ldx #3			; save crc for comparison
:	lda flash_data + rombank
	sta orgcrc,x
	bit flash_inc
	dex
	bpl :-

	jsr makecrctables	; init crc32
	jsr resetcrc

	lda #$3f		; checksum $3f00 bytes
	sta ctr
	ldy #0
:	lda flash_data + rombank
	jsr updatecrc
	bit flash_inc
	dey
	bne :-
	dec ctr
	bne :-

:	lda flash_data + rombank	; checksum last $fc bytes
	jsr updatecrc
	bit flash_inc
	iny
	cpy #252
	bne :-

	ldx #3
:	lda crc,x
	eor #$ff
	cmp orgcrc,x
	bne fail
	dex
	bpl :-

	jsr setrombank5
	ldax #$c000
	stax ptr
	ldy #0
	ldx #$40
:	lda flash_data + rombank
	sta (ptr),y
	bit flash_inc
	iny
	bne :-
	inc ptr + 1
	dex
	bne :-

	sei
	cld
	ldx #$ff
	txs

	ldx #0			; clear zp and stack
	txa
:	sta $00,x
	sta $0100,x
	inx
	bne :-

	jmp (warmstartvector)


setrombank5:
	bit flash_clear		; set flash address to $05c000
	bit flash_inc		; 1 1100 0000 0000 0000
	bit flash_shift
	bit flash_inc
	bit flash_shift
	bit flash_inc
	ldx #14
:	bit flash_shift
	dex
	bne :-
fail:
	rts


makecrctables:
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


resetcrc:
	lda #$ff
	sta crc
	sta crc+1
	sta crc+2
	sta crc+3
	rts


updatecrc:
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
	rts
