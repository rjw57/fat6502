	.include "drivecpu.i"

	.export reseth
	.export warmstart

	.importzp ptr

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_put
	.import debug_puthex
	.import debug_crlf


	.bss

lastkey:	.res 1


	.bss

gfxptr:	.res 3


	.code

warmstart:
reseth:
	sei
	ldx #$ff
	txs

	ldax msg_hello
	jsr debug_puts



	rti


	.rodata

msg_hello:
	.byte "Hello, world!", 13, 10, 0
msg_kbdinit:
	.byte "keyboard test, hammer away",13,10,0
