	.include "drivecpu.i"

	.export reseth

	.importzp ptr

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_puthex
	.import debug_crlf


	.bss

lastkey:	.res 1


	.segment "VOLZP", zeropage
	.segment "DEVZP", zeropage
	.segment "VOLBSS"
	.segment "DEVBSS"
	.segment "VOLVECTORS"
	.segment "DEVVECTORS"
	.segment "CTLVECTORS"
	.segment "DBGVECTORS"
	.segment "GFXVECTORS"


	.segment "RELOC"

; this is a dummy segment just to suppress an ld65 warning


	.code

reseth:
	lka
	sei
	cld
	ldx #$ff
	txs
	sta lastkey

	lda #%00000111		; initalize ctl reg
	ctl

	jsr debug_init

	ldax msg_kbdinit
	jsr debug_puts

	lda lastkey
	jsr debug_puthex
	jsr debug_crlf

loop:
	lka
	cmp lastkey
	beq loop
	sta lastkey
	jsr debug_puthex
	jsr debug_crlf
	jmp loop


	.rodata

msg_kbdinit:
	.byte "keyboard test, hammer away",13,10,0
