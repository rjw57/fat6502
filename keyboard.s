	.include "drivecpu.i"

	.export select_config

	.import debug_puthex
	.import debug_crlf

	.import clusterbuf
	.importzp ptr

	.import gfx_putchar
	.import gfx_gotoxy
	.import gfx_cls


	.code


; select config 0..9, 0 is default
select_config:
	lka
	cmp #$2b
	beq flash
	cmp #$1b
	beq serial
	cmp #$2c
	beq mrt
	cmp #$4d
	beq pong
	ldx #9
@checknext:
	cmp numbercodes,x
	beq @done
	dex
	bne @checknext		; nope, we don't check for 0
@done:

	txa
	clc
	rts

flash:
	lda #'F'
	.byte $2c
serial:
	lda #'S'

	sec
	rts


	.rodata

numbercodes:
	.byte $45, $16, $1e, $26, $25, $2e, $36, $3d, $3e, $46	; scan codes for 0..9


	.code

mrt:
	ldax (clusterbuf + 80 * 512 - 162)
	stax ptr
	ldy #0
	sty line
@nextline:
	gay

	gab_odd

	ldy #79
	ldx #79
:	lda (ptr),y
	eor #$ff
	gax
	gst
	dey
	dex
	bpl :-

	gab_even

	ldy #159
	ldx #79
:	lda (ptr),y
	eor #$ff
	gax
	gst
	dey
	dex
	bpl :-

	lda ptr
	sec
	sbc #160
	sta ptr
	bcs :+
	dec ptr+1
:
	inc line
	ldy line
	bne @nextline

	jmp *


	.code

pong:
	jsr resetgame
	jsr drawboard
	jsr drawbats
	jsr drawscore

newround:
	jsr drawball
	lda spacectr
	sta wait
:	jsr delay
	jsr moveplayers
	inc random
	lda spacectr
	cmp wait
	beq :-
	jsr setballdelta

pongmain:
	jsr moveplayers
	jsr delay
	jsr moveplayers

	jsr eraseball
	lda by
	clc
	adc bdy
	sta by

	lda bx
	clc
	adc bdx
	sta bx

	cmp #155
	beq @p2bounce
	cmp #1
	beq @p1bounce
@checky:
	lda by
	cmp #241
	bcc :+
	jsr bouncey
	jmp @draw
:	cmp #24
	bcs @draw
	jsr bouncey
@draw:
	jsr drawball

	jsr delay
	jmp pongmain

@p1bounce:
	lda by
	cmp p1e
	bcs @p2score
	clc
	adc #8
	cmp p1s
	bcc @p2score
	jsr bouncex
	jmp @checky

@p2bounce:
	lda by
	cmp p2e
	bcs @p1score
	clc
	adc #8
	cmp p2s
	bcc @p1score
	jsr bouncex
	jmp @checky

@p1score:
	inc p1
	jsr drawscore
	lda p1
	cmp #10
	beq @p1won
:	jsr resetball
	jmp newround

@p2score:
	inc p2
	jsr drawscore
	lda p2
	cmp #10
	beq @p2won
	jmp :-

@p1won:
@p2won:
	jmp *


delay:
	ldy #16
	ldx #0
:	inx
	bne :-
	dey
	bne :-
	rts


checkspace:
	lka
	cmp #space
	rts


bouncex:
	lda bdx
	eor #$ff
	clc
	adc #1
	sta bdx
	clc
	adc bx
	clc
	adc bdx
	sta bx
	rts


bouncey:
	lda bdy
	eor #$ff
	clc
	adc #1
	sta bdy
	clc
	adc by
	clc
	adc bdy
	sta by
	rts


moveplayers:
	jsr checkkbd
	ldx #0
	gax
	lda keys
	and #1
	beq @p1ckdn

	lda p1s
	cmp #24
	beq @p2ckup
	dec p1s
	dec p1e
	ldy p1s
	gay
	lda #$ff
	gst
	ldy p1e
	gay
	lda #0
	gst
	jmp @p2ckup

@p1ckdn:
	lda keys
	and #2
	beq @p2ckup

	lda p1e
	cmp #248
	beq @p2ckup
	ldy p1s
	gay
	lda #0
	gst
	ldy p1e
	gay
	lda #$ff
	gst
	inc p1s
	inc p1e
@p2ckup:
	ldx #79
	gax
	lda keys
	and #4
	beq @p2ckdn

	lda p2s
	cmp #24
	beq @p2ckdn
	dec p2s
	dec p2e
	ldy p2s
	gay
	lda #$ff
	gst
	ldy p2e
	gay
	lda #0
	gst
	jmp @ckdone
@p2ckdn:
	lda keys
	and #8
	beq @ckdone

	lda p2e
	cmp #248
	beq @ckdone
	ldy p2s
	gay
	lda #0
	gst
	ldy p2e
	gay
	lda #$ff
	gst
	inc p2s
	inc p2e
@ckdone:
	rts


drawboard:
	jsr gfx_cls

	gab_even

	ldy #16
	sty line
@nexttop:
	gay
	ldx #79
	lda #$ff
:	gax
	gst
	dex
	bpl :-
	inc line
	ldy line
	cpy #24
	bne @nexttop

	ldy #248
	sty line
@nextbot:
	gay
	ldx #79
	lda #$ff
:	gax
	gst
	dex
	bpl :-
	inc line
	ldy line
	bne @nextbot

	rts


resetgame:
	lda #0
	sta p1
	sta p2

	lda #120
	sta p1s
	sta p2s
	lda #120 + 32
	sta p1e
	sta p2e

	lda #0
	sta keys

resetball:
	lda #112 + 24 - 4
	sta by
	lda #79
	sta bx

	rts

setballdelta:
	lda random
	and #3
	tax
	lda dytab,x
	sta bdy
	lda dxtab,x
	sta bdx
	rts


drawbats:
	ldy #120
	lda #$ff
@draw:
	gay
	ldx #0
	gax
	gst
	ldx #79
	gax
	gst
	iny
	cpy #120 + 32
	bne @draw

	rts


drawball:
	ldy by
	lda bx
	lsr
	tax
	bcs @odd

@even:
	lda #8
	sta line
	lda #$ff
:	gay
	gax
	gst
	inx
	gst
	dex
	iny
	dec line
	bne :-

	rts	

@odd:
	lda #8
	sta line
:	gay
	lda #$0f
	gax
	gst
	inx
	lda #$ff
	gax
	gst
	inx
	lda #$f0
	gax
	gst
	dex
	dex
	iny
	dec line
	bne :-

	rts


eraseball:
	ldy by
	lda bx
	lsr
	tax
	bcs @odd

@even:
	lda #8
	sta line
	lda #0
:	gay
	gax
	gst
	inx
	gst
	dex
	iny
	dec line
	bne :-

	rts	

@odd:
	lda #8
	sta line
:	gay
	lda #0
	gax
	gst
	inx
	gax
	gst
	inx
	gax
	gst
	dex
	dex
	iny
	dec line
	bne :-

	rts


drawscore:
	ldx #30
	ldy #0
	jsr gfx_gotoxy

	lda p1
	ora #$30
	cmp #$3a
	beq @p1ten
	pha
	lda #'0'
	jsr gfx_putchar
	pla
	jsr gfx_putchar
	jmp @drawp2
@p1ten:
	lda #'1'
	jsr gfx_putchar
	lda #'0'
	jsr gfx_putchar

@drawp2:
	ldx #48
	ldy #0
	jsr gfx_gotoxy

	lda p2
	ora #$30
	cmp #$3a
	beq @p2ten
	pha
	lda #'0'
	jsr gfx_putchar
	pla
	jmp gfx_putchar
@p2ten:
	lda #'1'
	jsr gfx_putchar
	lda #'0'
	jmp gfx_putchar


checkkbd:
	lka
	cmp #0
	beq @done
	cmp #space
	bne :+
	inc spacectr
	rts
:	cmp #$f0
	beq @break

	ldx #3
:	cmp keytab,x
	beq @made
	dex
	bpl :-
	rts
@made:
	lda bittab,x
	ora keys
	sta keys
@done:
	rts

@break:
	lka
	cmp #0
	beq @break
	ldx #3
:	cmp keytab,x
	beq @broke
	dex
	bpl :-
	rts
@broke:
	lda bittab,x
	eor #$ff
	and keys
	sta keys
	rts


	.rodata

p1up	= $1c
p1dn	= $1a
p2up	= $42
p2dn	= $3a
space	= $29

keytab:
	.byte p1up, p1dn, p2up, p2dn
bittab:
	.byte 1, 2, 4, 8

dxtab:
	.byte $01, $ff, $01, $ff
dytab:
	.byte $02, $02, $fe, $fe


	.bss

line:		.res 1
p1:		.res 1
p2:		.res 1
p1s:		.res 1
p1e:		.res 1
p2s:		.res 1
p2e:		.res 1
bx:		.res 1
by:		.res 1
bdx:		.res 1
bdy:		.res 1
keys:		.res 1
spacectr:	.res 1
wait:		.res 1
random:		.res 1
