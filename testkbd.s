	.include "drivecpu.i"


	.export reseth
	.export warmstart

	.importzp ptr

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_puthex
	.import debug_crlf


	.bss

lastkey:	.res 1


	.code

reseth:
warmstart:
	sei
	cld
	ldx #$ff
	txs

	lda #%00000110		; initalize ctl reg
	ctl

	jsr debug_init

	ldax msg_kbdinit
	jsr debug_puts

loop:
	lka
	bcs loop
	jsr debug_puthex
	jsr debug_crlf
	jmp loop


	.rodata

msg_kbdinit:
	.byte "keyboard test, hammer away",13,10,0
