; controller selection and device scanning


	.include "drivecpu.i"


	.export ctl_select
	.export ctl_select_dev

	.import dev_set

	.import ide_scan

	.import ide_sizetab
	.import ide_drivetab
	.import ide_modeltab
	.import offset40

	.importzp devtype_none
	.importzp devtype_hd
	.importzp devtype_cd
	.importzp devtype_floppy

	.import vol_set_fs
	.importzp fs_fat12
	.importzp fs_fat32
	.importzp fs_iso9660

	.import debug_puts
	.import debug_puthex
	.import debug_putdigit
	.import debug_put


	.zeropage

msgptr:		.res 2


	.bss

devmap:		.res 4	; list of devices on current controller
numdevs:	.res 1	; number of devices on controller
currdev:	.res 1
currtype:	.res 1
size:		.res 4
sizechar:	.res 1
sizestr:	.res 5


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
	ldax floppymsg
	jsr debug_puts

	lda #fs_fat12		; kludge, fixme
	jsr vol_set_fs		; gotta put fs detection in the right place

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
	ldax idemsg
	jsr debug_puts

	lda #fs_fat32		; kludge, fixme
	jsr vol_set_fs		; gotta put fs detection in the right place

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
	sta currtype

	inc numdevs

	ldax founddevmsg
	jsr debug_puts

	lda currdev
	jsr debug_putdigit

	lda currtype
	cmp #devtype_cd
	bne @notcd

	ldax cdmsg
	jsr debug_puts
	jmp @printcolon
@notcd:
	lda currdev
	asl
	asl
	tax
	ldy #0
:	lda ide_sizetab,x
	sta size,y
	inx
	iny
	cpy #4
	bne :-

	jsr printsize

@printcolon:
	ldax colonmsg
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


; print size as a friendly number
printsize:
	lda #' '
	jsr debug_put
	lda #'('
	jsr debug_put

	asl size
	rol size+1
	rol size+2
	rol size+3

	lda #3
	sta sizechar

@check10zero:
	lda size+3
	bne @nope
	lda size+2
	and #$c0
@nope:
	bne @print

	jsr shift10bits

	dec sizechar
	bne @check10zero

@print:
	lda size+3
	sta size
	lda #0
	asl size+2
	rol size
	rol
	asl size+2
	rol size
	rol
	sta size+1

	ldx #3
@loop:
	jsr div16
	sta sizestr,x
	dex
	bpl @loop

	ldx #0			; eliminate leading 0s
:	lda sizestr,x
	bne @foundnumber
	inx
	cpx #3
	bne :-

@foundnumber:
:	lda sizestr,x
	jsr debug_putdigit
	inx
	cpx #4
	bne :-

	lda #' '
	jsr debug_put
	ldx sizechar
	lda sizechartab,x
	jsr debug_put
	lda #'B'
	jsr debug_put
	lda #')'
	jmp debug_put


; divide a 16-bit number (in size) by the 10. result -> size,
; remainder in a. modified version of Steve Judd's 32-bit divide.
div16:
 	lda #00
	ldy #$10
@loop: 	asl size
	rol size+1
	rol
	cmp #10
	bcc :+
	sbc #10
	inc size
: 	dey
	bne @loop
	rts


shift10bits:
	lda size+2
	sta size+3
	lda size+1
	sta size+2
	lda size
	sta size+1
	lda #0
	sta size
	asl size+1
	rol size+2
	rol size+3
	asl size+1
	rol size+2
	rol size+3
	rts


; select a device on the currently active controller
ctl_select_dev:
	tax
	lda devmap,x
	bne :+
	sec
	rts
:	jmp dev_set


sizechartab:
	.byte " ", "k", "M", "G"
founddevmsg:
	.byte "Found device ",0
colonmsg:
	.byte ", ",0
floppymsg:
	.byte "Searching for boot devices on floppy controller",13,10,0
idemsg:
	.byte "Searching for boot devices on IDE controller",13,10,0
cdmsg:
	.byte " (CD-ROM)",0
