	.include "drivecpu.i"

	.export reseth
	.export warmstart

	.import relocate

	.import init232boot

	.segment "VOLZP" : zeropage
	.segment "DEVZP" : zeropage
	.segment "VOLBSS"
	.segment "DEVBSS"
	.segment "VOLVECTORS"
	.segment "DEVVECTORS"
	.segment "CTLVECTORS"
	.segment "DBGVECTORS"
	.segment "GFXVECTORS"


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
