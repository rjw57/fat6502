	.include "drivecpu.i"

	.export reseth

	.import init232boot

	.import debug_init


	.segment "VOLZP", zeropage
	.segment "DEVZP", zeropage
	.segment "VOLBSS"
	.segment "DEVBSS"
	.segment "VOLVECTORS"
	.segment "DEVVECTORS"
	.segment "CTLVECTORS"
	.segment "DBGVECTORS"
	.segment "GFXVECTORS"


	.code

reseth:
	sei
	cld
	ldx #$ff
	txs

	lda #%00000110		; initalize ctl reg
	ctl

	jsr debug_init

	jmp init232boot
