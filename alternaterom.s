	.include "drivecpu.i"

	.export checkaltrom

	.import makecrctables
	.import resetcrc
	.import updatecrc
	.importzp crc

	.importzp ptr

	.import warmstartvector


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
