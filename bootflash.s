; quick and dirty flash programming utility
; this code assumes that no dummy reads are done with addr,x and addr,y!!!


	.include "drivecpu.i"

	.export reseth

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


	.segment "VOLZP", zeropage
	.segment "DEVZP", zeropage
	.segment "VOLBSS"
	.segment "DEVBSS"
	.segment "VOLVECTORS"
	.segment "DEVVECTORS"
	.segment "CTLVECTORS"
	.segment "DBGVECTORS"
	.segment "GFXVECTORS"
	.segment "RELOC"


flash_clear	= $3f60
flash_shift	= $3f66
flash_inc	= $3f68
flash_data	= $3f6c

flashbuf	= $2000


	.zeropage

addr:	.res 3
len:	.res 2
bank:	.res 1
maxlen:	.res 1
hexlen:	.res 1
hexbuf:	.res 6


	.code

reseth:
	sei
	cld
	ldx #$ff
	txs

	lda #%00000110		; initalize ctl reg
	ctl

	jsr debug_init

restart:
	ldax initmsg
	jsr debug_puts

	ldax flashidmsg
	jsr debug_puts
	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$90
	jsr write5555quick
	bit flash_clear
	lda flash_data
	jsr debug_puthex
	bit flash_inc
	lda flash_data
	jsr debug_puthex
	jsr debug_crlf
	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$f0
	jsr write5555quick

	ldax addrmsg
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

	ldax lengthmsg
	jsr debug_puts
	lda #4
	jsr gethex
	jsr debug_crlf
	lda hexbuf+1
	sta len
	lda hexbuf+2
	sta len+1

	ldax erasemsg
	jsr debug_puts

	lda #$aa
	jsr write5555
	lda #$55
	jsr write2aaaquick
	lda #$80
	jsr write5555quick
	lda #$aa
	;jsr write5555
	sta flash_data
	lda #$55
	jsr write2aaaquick
	bit flash_clear
	lda addr+2
	lsr
	bcc :+
	bit flash_inc
:	ldx #16
:	bit flash_shift
	dex
	bne :-
	ldy bank
	lda #$30
	sta flash_data,y

	lda #$ff
:	cmp flash_data,y
	bne :-

	ldax waitmsg
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
	ldax okmsg
	jsr debug_puts

	inc addr+1
	bne :+
	inc addr+2
:
	dec len+1
	bne flash

	ldax donemsg
	jsr debug_puts
	jmp restart

@error:
	ldax errormsg
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

	bit flash_clear		; pgm address

	lda addr+2		; 17th bit
	lsr
	bcc :+
	bit flash_inc
:
	ldy #8
	lda addr+1
@hiaddr:
	bit flash_shift
	asl
	bcc :+
	bit flash_inc
:	dey
	bne @hiaddr

	ldy #8
	txa
@loaddr:
	bit flash_shift
	asl
	bcc :+
	bit flash_inc
:	dey
	bne @loaddr

	lda flashbuf,x
	ldy bank
	sta flash_data,y

:	lda flash_data,y
	cmp flashbuf,x
	bne :-

	inx
	beq :+
	jmp @unlock

:	clc
	rts


write5555:
	bit flash_clear
	bit flash_inc

	bit flash_shift
	bit flash_shift
	bit flash_inc

	bit flash_shift
	bit flash_shift
	bit flash_inc

	bit flash_shift
	bit flash_shift
	bit flash_inc

	bit flash_shift
	bit flash_shift
	bit flash_inc

	bit flash_shift
	bit flash_shift
	bit flash_inc

	bit flash_shift
	bit flash_shift
	bit flash_inc

	bit flash_shift
write5555quick:
	bit flash_shift
	bit flash_inc

	sta flash_data
	rts


write2aaa:
	bit flash_clear
	bit flash_inc
	bit flash_shift

	bit flash_shift
	bit flash_inc
	bit flash_shift

	bit flash_shift
	bit flash_inc
	bit flash_shift

	bit flash_shift
	bit flash_inc
	bit flash_shift

	bit flash_shift
	bit flash_inc
	bit flash_shift

	bit flash_shift
	bit flash_inc
	bit flash_shift

	bit flash_shift
	bit flash_inc
write2aaaquick:
	bit flash_shift

	sta flash_data
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


	.rodata

scantable:
	.byte 0
	.byte $45,$16,$1e,$26,$25,$2e,$36,$3d,$3e,$46
	.byte $1c,$32,$21,$23,$24,$2b
	.byte $2d,$1d
	.byte $66,$5a
scantoasc:
	.byte 0,"0123456789"
	.byte "abcdef"
	.byte "rw"
	.byte 8,10
exttable:
	.byte 0
exttoasc:
	.byte 0


initmsg:
	.byte "C1 quick and dirty flash util",13,10,0

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
