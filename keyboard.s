	.include "drivecpu.i"

	.export select_config

	.import debug_puthex
	.import debug_crlf


	.code


; select config 0..9, 0 is default
select_config:
	lka
	ldx #9
@checknext:
	cmp @numbercodes,x
	beq @done
	dex
	bne @checknext		; nope, we don't check for 0
@done:

	txa
	clc
	rts


	.rodata

@numbercodes:
	.byte $45, $16, $1e, $26, $25, $2e, $36, $3d, $3e, $46	; scan codes for 0..9
