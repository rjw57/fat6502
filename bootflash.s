; quick and dirty flash programming utility
; this code assumes that no dummy reads are done with addr,x and addr,y!!!


	.include "drivecpu.i"

	.export reseth
	.export warmstart

	.import timestamp

	.import __RELOC_SIZE__
	.import __RELOC_RUN__
	.import __RELOC_LOAD__

	.import debug_init
	.import debug_puts
	.import debug_puthex
	.import debug_crlf
	.import debug_putdigit
	.import debug_put
	.import debug_get


	.segment "RELOC"


flashbuf	= $2000


	.zeropage

addr:	.res 3
len:	.res 2
bank:	.res 1
maxlen:	.res 1
hexlen:	.res 1
hexbuf:	.res 6
ctr1:	.res 1
ctr2: 	.res 1
xtemp:	.res 1
atemp:	.res 1


	.macro bit_flash_clear
	pha
	txa
	pha
	ldx #dev_clk2
	lda #flash_clear
	sca
	ldx #dev_release
	sca
	pla
	tax
	pla
	.endmacro

	.macro bit_flash_inc
	pha
	txa
	pha
	ldx #dev_clk2
	lda #flash_inc
	sca
	ldx #dev_release
	sca
	pla
	tax
	pla
	.endmacro

	.macro bit_flash_shift
	pha
	txa
	pha
	ldx #dev_clk2
	lda #flash_shift
	sca
	ldx #dev_release
	sca
	pla
	tax
	pla
	.endmacro

	.macro lda_flash_data
	stx xtemp
	ldx #dev_clk2
	lda #flash_data
	sca
	ild
	ldx #dev_release
	sca
;	pha
	ldx xtemp
;	pla
	.endmacro

	.macro lda_flash_data_y
	stx xtemp
	ldx #dev_clk2
	tya
	php
	clc
	adc #flash_data
	plp
	sca
	ild
	ldx #dev_release
	sca
;	pha
	ldx xtemp
;	pla
	.endmacro

	.macro sta_flash_data
	php
	pha
	stx xtemp
	ldx #dev_clk2
	lda #flash_data
	sca
	pla
	ist
	ldx #dev_release
	sca
	ldx xtemp
	plp
	.endmacro

	.macro sta_flash_data_y
	php
	pha
	stx xtemp
	ldx #dev_clk2
	tya
	clc
	adc #flash_data
	sca
	pla
	ist
	ldx #dev_release
	sca
	ldx xtemp
	plp
	.endmacro


	.code

reseth:
warmstart:
	sei
	cld
	ldx #$ff
	txs

;	lda #%00000110		; initalize ctl reg
;	ctl

	jsr debug_init

	ldax #initmsg
	jsr debug_puts

	ldax #flashidmsg
	jsr debug_puts
	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$90
	jsr write5555quick
	bit_flash_clear
	lda_flash_data
	jsr debug_puthex
	bit_flash_inc
	lda_flash_data
	jsr debug_puthex
	jsr debug_crlf
	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$f0
	jsr write5555quick

restart:
	ldax #flashormemmsg
	jsr debug_puts
@select:
	jsr debug_get
	cmp #'f'
	beq programflash
	cmp #'F'
	beq programflash
	cmp #'m'
	bne @select

	jmp viewflash


programflash:
	ldax #addrmsg
	jsr debug_puts
	lda #6
	jsr gethex
	jsr debug_crlf
	ldx #2
:	lda hexbuf,x
	sta addr,x
	dex
	bpl :-
	lda addr+2
	lsr
	sta bank

	ldax #lengthmsg
	jsr debug_puts
	lda #4
	jsr gethex
	jsr debug_crlf
	lda hexbuf+1
	sta len
	lda hexbuf+2
	sta len+1

	ldax #warningmsg
	jsr debug_puts
	jsr debug_get
	cmp #' '
	beq :+
	jmp restart
:

	ldax #erasemsg
	jsr debug_puts

	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$80
	jsr write5555quick
	lda #$aa
	;jsr write5555
	sta_flash_data
	lda #$55
	jsr write2aaaquick
	bit_flash_clear
	lda addr+2
	lsr
	bcc :+
	bit_flash_inc
:	ldx #16
:	bit_flash_shift
	dex
	bne :-
	ldy bank
	lda #$30
	sta_flash_data_y

:	lda_flash_data_y
	cmp #$ff
	bne :-

	ldax #waitmsg
	jsr debug_puts

flash:
	jsr printaddr

	ldx #0
@getbyte:
	jsr debug_get
	;txa
	sta flashbuf,x
	inx
	bne @getbyte

	jsr programpage

	bcs @error
	ldax #okmsg
	jsr debug_puts

	inc addr+1
	bne :+
	inc addr+2
:
	dec len+1
	bne flash

	ldax #donemsg
	jsr debug_puts
	jmp restart

@error:
	ldax #errormsg
	jsr debug_puts
	jmp restart


printaddr:
	lda #'$'
	jsr debug_put
	ldx #2
:	lda addr,x
	jsr debug_puthex
	dex
	bpl :-
	rts


programpage:
	ldx #0

@unlock:
	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$a0
	jsr write5555quick

	bit_flash_clear		; pgm address

	lda addr+2		; 17th bit
	lsr
	bcc :+
	bit_flash_inc
:
	ldy #8
	lda addr+1
@hiaddr:
	bit_flash_shift
	asl
	bcc :+
	bit_flash_inc
:	dey
	bne @hiaddr

	ldy #8
	txa
@loaddr:
	bit_flash_shift
	asl
	bcc :+
	bit_flash_inc
:	dey
	bne @loaddr

	lda flashbuf,x
	ldy bank
	sta_flash_data_y

:	lda_flash_data_y
	cmp flashbuf,x
	bne :-

	inx
	beq :+
	jmp @unlock

:	clc
	rts


write5555:
	bit_flash_clear
	bit_flash_inc

	bit_flash_shift
	bit_flash_shift
	bit_flash_inc

	bit_flash_shift
	bit_flash_shift
	bit_flash_inc

	bit_flash_shift
	bit_flash_shift
	bit_flash_inc

	bit_flash_shift
	bit_flash_shift
	bit_flash_inc

	bit_flash_shift
	bit_flash_shift
	bit_flash_inc

	bit_flash_shift
	bit_flash_shift
	bit_flash_inc

	bit_flash_shift
write5555quick:
	bit_flash_shift
	bit_flash_inc

	sta_flash_data
	rts


write2aaa:
	bit_flash_clear
	bit_flash_inc
	bit_flash_shift

	bit_flash_shift
	bit_flash_inc
	bit_flash_shift

	bit_flash_shift
	bit_flash_inc
	bit_flash_shift

	bit_flash_shift
	bit_flash_inc
	bit_flash_shift

	bit_flash_shift
	bit_flash_inc
	bit_flash_shift

	bit_flash_shift
	bit_flash_inc
	bit_flash_shift

	bit_flash_shift
	bit_flash_inc
write2aaaquick:
	bit_flash_shift

	sta_flash_data
	rts


gethex:
	sta maxlen
	lda #0
	sta hexlen
@getkey:
	jsr debug_get
	;jsr kbd_get
	cmp #8
	bne :+

	lda hexlen
	beq @getkey
	dec hexlen
	jmp @getkey

:	jsr debug_put
	jsr asciitohex
	ldx hexlen
	sta hexbuf,x
	inx
	cpx maxlen
	beq @done
	stx hexlen
	jmp @getkey

@done:
	lda hexbuf
	asl
	asl
	asl
	asl
	ora hexbuf+1
	pha
	lda hexbuf+2
	asl
	asl
	asl
	asl
	ora hexbuf+3
	sta hexbuf+1
	pla
	sta hexbuf+2
	lda hexbuf+4
	asl
	asl
	asl
	asl
	ora hexbuf+5
	sta hexbuf
	rts


asciitohex:
	sec
	sbc #$30
	cmp #10
	bcc @skip
	;sec
	sbc #7
	and #$0f
@skip:
	rts


kbd_get:
:	lka			; get byte from kbdfifo
	bcs :-			; carry = empty

	cmp #$f0		; break code?
	bne @make
@break:
:	lka			; eat next key
	bcs :-
	bcc kbd_get
@make:
	cmp #$e0		; cursor keys are extended codes
	beq @extended

	ldx #0
:	cmp scantable,x
	beq :+
	inx
	bne :-
:	lda scantoasc,x
	clc
	rts

@extended:
:	lka			; eat next key
	bcs :-
	cmp #$f0
	beq @break

	lda #0			; no extended codes
	clc
	rts

	ldx #0
:	cmp exttable,x
	beq :+
	inx
	bne :-
:	lda exttoasc,x
	clc
	rts


viewflash:
	ldax #addrmsg
	jsr debug_puts
	lda #6
	jsr gethex
	jsr debug_crlf
	ldx #2
:	lda hexbuf,x
	sta addr,x
	dex
	bpl :-
	lda addr+2
	lsr
	sta bank

	bit_flash_clear		; pgm address

	lda addr+2		; 17th bit
	lsr
	bcc :+
	bit_flash_inc
:
	ldy #8
	lda addr+1
@hiaddr:
	bit_flash_shift
	asl
	bcc :+
	bit_flash_inc
:	dey
	bne @hiaddr

	ldy #8
	lda addr
@loaddr:
	bit_flash_shift
	asl
	bcc :+
	bit_flash_inc
:	dey
	bne @loaddr

	lda #16
	sta ctr1

@nextline:
	lda addr+2
	jsr debug_puthex
	lda addr+1
	jsr debug_puthex
	lda addr
	jsr debug_puthex
	lda #':'
	jsr debug_put

	lda #4
	sta ctr2
@next:
	lda #' '
	jsr debug_put
	ldx #4
	ldy bank

:	lda_flash_data_y
	jsr debug_puthex
	bit_flash_inc
	dex
	bne :-

	dec ctr2
	bne @next

	jsr debug_crlf

	lda addr
	clc
	adc #16
	sta addr
	bcc :+
	inc addr+1
	bne :+
	inc addr+2
:
	dec ctr1
	bne @nextline

	jmp restart


	.rodata

scantable:
	.byte 0
	.byte $45,$16,$1e,$26,$25,$2e,$36,$3d,$3e,$46
	.byte $1c,$32,$21,$23,$24,$2b
	.byte $2d,$1d,$2b,$3a
	.byte $66,$5a
scantoasc:
	.byte 0,"0123456789"
	.byte "abcdef"
	.byte "rwfm"
	.byte 8,10
exttable:
	.byte 0
exttoasc:
	.byte 0


initmsg:
	.byte "C1 quick and dirty flash util",13,10,0

warningmsg:
	.byte "Warning: the whole 64K sector will be erased!",13,10
	.byte "Press space to start, any other key to cancel.",13,10,0

addrmsg:
	.byte "24-bit start address: $",0

lengthmsg:
	.byte "16-bit length: $",0

erasemsg:
	.byte "Erasing sector...",13,10,0

waitmsg:
	.byte "Waiting for data...",13,10,0

okmsg:
	.byte 13,10,0

donemsg:
	.byte "Done.",13,10,0

errormsg:
	.byte " failed!",13,10,0

flashidmsg:
	.byte "Flash ID: ",0

flashormemmsg:
	.byte "F to program a flash, M to view flash contents",13,10,0
