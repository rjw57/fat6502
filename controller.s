; controller selection and device scanning


	.include "drivecpu.i"


	.export ctl_select
	.export ctl_select_dev

	.import dev_set

	.import ide_scan

	.import ide_drivetab
	.import ide_modeltab
	.import offset40

	.importzp devtype_none
	.importzp devtype_hd
	.importzp devtype_cd
	.importzp devtype_floppy

	.import debug_puts
	.import debug_puthex
	.import debug_put


	.zeropage

msgptr:		.res 2


	.bss

devmap:		.res 4	; list of devices on current controller
numdevs:	.res 1	; number of devices on controller
currdev:	.res 1


	.code

; select controller. returns number of devices.
ctl_select:
	cmp #0
	beq @select_floppy
	cmp #1
	beq @select_ide
	sec
	rts

@select_floppy:
	lda #<floppymsg
	ldx #>floppymsg
	jsr debug_puts

	lda #devtype_floppy	; a single floppy drive
	sta devmap
	lda #0
	sta devmap + 1
	sta devmap + 2
	sta devmap + 3
	lda #1			; one device on this controller
	clc
	rts

@select_ide:
	lda #<idemsg
	ldx #>idemsg
	jsr debug_puts

	jsr ide_scan		; scan ide bus

	ldx #3
:	lda ide_drivetab,x
	sta devmap,x
	dex
	bpl :-

	ldy #0
	sty numdevs
@checkide:
	sty currdev
	lda ide_drivetab,y
	beq @nextide

	inc numdevs

	lda #<founddevmsg
	ldx #>founddevmsg
	jsr debug_puts

	lda currdev
	jsr debug_puthex

	lda #<colonmsg
	ldx #>colonmsg
	jsr debug_puts

	lda #<ide_modeltab
	clc
	ldy currdev
	adc offset40,y
	sta msgptr
	lda #>ide_modeltab
	adc #0
	sta msgptr+1
	ldy #0
@printide:
	lda (msgptr),y
	jsr debug_put
	iny
	cpy #40
	bne @printide

	lda #13
	jsr debug_put
	lda #10
	jsr debug_put

@nextide:
	ldy currdev
	iny
	cpy #4
	bne @checkide

	lda numdevs
	clc
	rts


; select a device on the currently active controller
ctl_select_dev:
	tax
	lda devmap,x
	bne :+
	sec
	rts
:	jmp dev_set


founddevmsg:
	.byte "Found device ",0
colonmsg:
	.byte ": ",0
floppymsg:
	.byte "Searching for boot devices on floppy controller",13,10,0
idemsg:
	.byte "Searching for boot devices on IDE controller",13,10,0
