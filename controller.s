; controller selection and device scanning


	.include "drivecpu.i"


	.export ctl_select
	.export ctl_select_dev
	.export devmap

	.import dev_set
	.import dev_find_volume

	.import ide_scan

	.import ide_sizetab
	.import ide_drivetab
	.import ide_modeltab
	.import offset40

	.importzp devtype_none
	.importzp devtype_hd
	.importzp devtype_cd
	.importzp devtype_floppy
	.importzp devtype_rom

	.import vol_set_fs
	.importzp fs_fat12
	.importzp fs_fat16
	.importzp fs_fat32
	.importzp fs_iso9660

	.import debug_puts
	.import debug_putdigit
	.import debug_put


	.zeropage

msgptr:		.res 2


	.bss

devmap:		.res 4	; list of devices on current controller
numdevs:	.res 1	; number of devices on controller
currdev:	.res 1
currtype:	.res 1
size:		.res 6
prefixIndex:	.res 1
digitCount:	.res 1
decimalPlaces:	.res 1




	.segment "CTLVECTORS"

	; jump table at $ffxx

ctl_select:		jmp _ctl_select
ctl_select_dev:		jmp _ctl_select_dev


	.code

; select controller. returns number of devices.
_ctl_select:
	cmp #0
	beq @select_floppy
	cmp #1
	beq @select_ide
	cmp #2
	beq @select_rom
	sec
	rts

@select_floppy:
	ldax #floppymsg
	jsr debug_puts

	lda #fs_fat12		; kludge, fixme
	jsr vol_set_fs		; gotta put fs detection in the right place

	lda #devtype_floppy	; one floppy drive
	sta devmap
	lda #0
	sta devmap + 1
	sta devmap + 2
	sta devmap + 3
	lda #1			; one device on this controller
	clc
	rts

@select_rom:
	ldax #rommsg
	jsr debug_puts

	lda #fs_fat16		; kludge, fixme
	jsr vol_set_fs		; gotta put fs detection in the right place

	lda #devtype_rom	; one rom drive
	sta devmap
	lda #0
	sta devmap + 1
	sta devmap + 2
	sta devmap + 3
	lda #1			; one device on this controller
	clc
	rts

@select_ide:
	ldax #idemsg
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
	sta currtype

	inc numdevs

	ldax #founddevmsg
	jsr debug_puts

	lda currdev
	jsr debug_putdigit

	lda currtype
	cmp #devtype_cd
	bne @notcd

	ldax #cdmsg
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
	ldax #colonmsg
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


;------------------------------------------------------------------------------
;
; printsize
;
; function
;   print size as a friendly number
;
; before calling
;   on entry, write the size in 512 byte sectors to the first four bytes
;   of 'size', lsb first.  Anything from zero to 0xffffffff is valid
;
; requires
;
;	debug_put     - prints the char given in A
;	debug_putdigit     - prints the digit given in A
;   printsz(addr) - macro that calls a function to
;                   print the null terminated string at addr
;
; on return
;	a,x,y and size all trashed.
;
; RAM required
;   9 bytes for size, _prefixIndex, _digitCount, _decimalPlaces
;   the rest should be ROMable
;
; stack required
;   ~6 bytes for internal function calls,
;   +4 bytes for integral part of digits
;   + whatever debug_putdigit or printsz() requires
;
;------------------------------------------------------------------------------


;
; Implementation notes
;
; Most of the code treats size as a 16.32 fixed point number (lsb first)
; scaleAndSetPrefix starts by doubling the number to get a fixed-point size
; in Terabytes, then repeatedly shifts left by 10 and decrements the 
; unit index until the size is >= 1.0 units
;
; Note that all text is currently in petscii - easier to test that way ;)
;


	.code

printsize:
	ldax #preamble
	jsr debug_puts
	lda size
	ora size+1
	ora size+2
	ora size+3
	bne @nz
	jsr debug_putdigit
	ldx #0
	jmp @pp

@nz:
	jsr @scaleAndSetPrefix
	jsr @printScaledSize
	ldx prefixIndex
@pp:
	lda #32
	jsr debug_put
	lda prefixes,x
	jsr debug_put
	ldax #postamble
	jmp debug_puts


@scaleAndSetPrefix:
        ; don't call this with a size of zero or it will never terminate!!

	; set prefix to T
	lda #3
	sta prefixIndex
	lda #0
	sta size+5
	asl size
	rol size+1
	rol size+2
	rol size+3
	rol
	and #1
	sta size+4
	lda size+4
	; size now contains fixed point size in Terabytes
	bne @scaleDone
@asl10:
	jsr @asl8size
	jsr @asl1size
	jsr @asl1size
	dec prefixIndex
	lda prefixIndex
	beq @scaleDone   ; print 1 sector as 0.5kB
	lda size+4
	ora size+5
	beq @asl10
@scaleDone:
	rts
	


@printScaledSize:

	; first add 0.5, 0.05 or 0.005 units to size to round to nearest
	ldx #0
	lda size+5
	bne @addRound
	lda size+4
	cmp #100
	bcs @addRound
	inx
	cmp #10
	bcs @addRound
	inx
@addRound:
	stx decimalPlaces
	clc
	lda roundLo,x
	adc size+2
	sta size+2
	lda roundHi,x
	adc size+3
	sta size+3
	bcc @ni
	inc size+4
	bne @ni
	inc size+5
@ni:
	; end of rounding


	; push digits onto stack

	lda #0
	sta digitCount
@convertMore:
	jsr @div16by10
	pha
	inc digitCount
	lda size+5
	ora size+4
	bne @convertMore

	; only need these lines if the rounding code above is ditched
	; lda #3
	; sec
	; sbc digitCount
	; sta decimalPlaces

	; pop digits and print them
@more:
	pla
	jsr debug_putdigit
	dec digitCount
	bne @more

	; stuff after this point is for fractions of whatever the selected unit is

	dec decimalPlaces
	bmi @printDone
	lda #46
	jsr debug_put

@dplp:
	jsr @multSizeBy10

	lda size+4
	jsr debug_putdigit
	lda #0
	sta size+4

	dec decimalPlaces
	bpl @dplp
@printDone:
	rts


@asl8size:
	lda size+4
	sta size+5

	lda size+3
	sta size+4

	lda size+2
	sta size+3

	lda size+1
	sta size+2

	lda size
	sta size+1
	lda #0
	sta size
	rts

@asl1size:
	asl size
	rol size+1
	rol size+2
	rol size+3
	rol size+4
	rol size+5
	rts


; divide a 16-bit number (in size+4,size+5) by the 10. result -> size,
; remainder in a. modified version of Steve Judd's 32-bit divide.
@div16by10:
	lda #00
	ldy #$10
@loop:
	asl size+4
	rol size+5
	rol
	cmp #10
	bcc @sk10
	sbc #10
	inc size+4
@sk10:
	dey
	bne @loop
	rts


@multSizeBy10:
	; just operates on bytes 3 and 4
	lda size+3
	asl
	rol size+4
	asl
	rol size+4
	adc size+3
	sta size+3
	bcc @ni2
	inc size+4
@ni2:
	; have now multiplied by 5
	asl size+3
	rol size+4
	rts


; select a device on the currently active controller
_ctl_select_dev:
	tax
	lda devmap,x
	bne :+
@error:
	sec
	rts
:	jmp dev_set


	.rodata

roundLo:
	.byt   0,<(3276),<(327)
roundHi:
	.byt 128,>(3276),>(327)

preamble:
	.byte " (",0
postamble:
	.byte "B)",0

prefixes:
	.byte "k", "M", "G", "T"


founddevmsg:
	.byte "Found device ",0
colonmsg:
	.byte ", ",0
floppymsg:
	.byte "Searching for boot devices on floppy controller",13,10,0
idemsg:
	.byte "Searching for boot devices on IDE controller",13,10,0
rommsg:
	.byte "Searching for boot devices in flash rom",13,10,0
cdmsg:
	.byte " (CD-ROM)",0
