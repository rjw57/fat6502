	.include "drivecpu.i"

	.export select_config


	.code


; select config 0..9, 0 is default
select_config:
	ldx #0
@getcode:
	lka			; grab a scancode from the keyboard
	cmp #$00		; if it's 0 the previous one was the last
	beq @gotlast
	tax			; keep the code in x
	bne @getcode

@gotlast:
	txa
	ldx #9
@checknext:
	cmp @numbercodes,x
	beq @done
	dex
	bne @checknext		; nope, we don't check for 0
@done:

	txa
	lda #0
	clc
	rts


	.rodata

@numbercodes:
	.byte $45, $16, $1e, $26, $25, $2e, $36, $3d, $3e, $46	; scan codes for 0..9
