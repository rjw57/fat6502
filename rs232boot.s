	.include "drivecpu.i"

	.export reseth
	.export warmstart

	.import relocate

	.import init232boot


	.code

reseth:
warmstart:
	sei
	cld
	ldx #$ff
	txs

	lda #%00000110		; initalize ctl reg
	ctl

	jsr relocate

	jmp init232boot
