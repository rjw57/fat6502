	.include "drivecpu.i"

	.export checkaltrom

	.import makecrctables
	.import resetcrc
	.import updatecrc
	.importzp crc

	.import debug_init
	.import debug_puts
	.import debug_puthex
	.import debug_crlf


	.segment "RELOC"

orgcrc:		.res 4
ctr:		.res 1

rombank		= 3


checkaltrom:
	jsr debug_init		;;;;; remove me!

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

	ldax orgcrcmsg
	jsr debug_puts
	ldx #3			; save crc for comparison
:	lda flash_data + rombank
	sta orgcrc,x
	jsr debug_puthex
	bit flash_inc
	dex
	bpl :-
	jsr debug_crlf

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

	ldax calccrcmsg
	jsr debug_puts
	ldx #3
:	lda crc,x
	eor #$ff
	jsr debug_puthex
	dex
	bpl :-
	jsr debug_crlf

	jmp *
	rts


orgcrcmsg:
	.byte "Original CRC-32 checksum: ",0

calccrcmsg:
	.byte "Calculated CRC-32 checksum: ",0
