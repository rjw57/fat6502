	.include "drivecpu.i"

	.export select_config
	.export mrt, pong

	.import debug_puthex
	.import debug_crlf

	.import reseth

	.import clusterbuf
	.importzp ptr, ptr3

	.import gfx_putchar
	.import gfx_gotoxy
	.import gfx_cls


	.code

; select config 0..9, 0 is default
select_config:
	lka
	bcs @default
	cmp #$2c
	beq mrt
	cmp #$4d
	beq pong
	ldx #11
@checknext:
	cmp numbercodes,x
	beq @done
	dex
	bpl @checknext
	bmi select_config	; loop until we get a valid scancode
				; or fifo is empty. that should do it
@default:
	lda #'0'		; default to config 0
	sec
	rts
@done:
:	lka			; flush keyboard queue
	bcc :-
	lda asciicodes,x
	clc
	rts

	.rodata

numbercodes:
	.byte $45, $16, $1e, $26, $25, $2e, $36, $3d, $3e, $46, $1b, $2b
asciicodes:
	.byte '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'S', 'F'


	.code

mrt:
	ldax #clusterbuf
	stax ptr
	lda #0
	sta ptr3
	lda #$c0
	sta ptr3 + 1
	lda #$0b
	sta ptr3 + 2

	ldy #0
	ldx #$40
@next:
	lda (ptr),y
	sam ptr3

	inc ptr3
	bne :+
	inc ptr3 + 1
:
	iny
	bne @next

	inc ptr
	dex
	bne @next

@waitspace:
	lka
	bcs @waitspace
	bvs @waitspace
	bmi @waitspace
	cmp #$29
	bne @waitspace

	jmp reseth


; 7-sept-2004 macros for CPC gfx hack:

; set graphics cursor x position
        .macro gax
        stx gfx_x
        .endmacro

; set graphics cursor y position, bits 1..8
        .macro gay
        sty gfx_y
        .endmacro

; write to graphics ram
        .macro gst
        jsr gfx_gst
        .endmacro


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
	cmp #185
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
	ldy #10
	ldx #0
:	inx
	bne :-
	dey
	bne :-
	rts


checkspace:
	lka
	bcs @notspace
	bvs @notspace
	bmi @notspace
	cmp #space
	rts
@notspace:
	cmp #0		; lka should never return 0
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
	cmp #192
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
	cmp #192
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

	ldy #192
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
	cpy #200
	bne @nextbot

	rts


resetgame:
	lda #0
	sta p1
	sta p2

	lda #96
	sta p1s
	sta p2s
	lda #96 + 32
	sta p1e
	sta p2e

	lda #0
	sta keys

resetball:
	lda #88 + 24 - 4
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
	ldy #96
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
	cpy #96 + 32
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
	bcs @done
	bvs @done
	bmi @break
	cmp #space
	bne :+
	inc spacectr
	rts
:
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


; 07-sept-2004 add CPC gfx hack

; entry point and parameter storage for CPC gfx hack

; gst routine here... no separate label

gfx_gst:
; gfx_x_gst:
        sta gfx_x_data

;save everything

        php
        txa
        pha
        tya
        pha

	lda #$0b
	sta gfx_addr_hi

	;80 = 16 * 5
	lda #0
	sta gfx_addr_mid
	lda gfx_y
	lsr
	lsr
	lsr
	sta gfx_addr_lo
	asl
	asl
	;clc
	adc gfx_addr_lo
	asl
	rol gfx_addr_mid
	asl
	rol gfx_addr_mid
	asl
	rol gfx_addr_mid
	asl
	rol gfx_addr_mid
	;clc
	adc gfx_x
	sta gfx_addr_lo
	bcc :+
	inc gfx_addr_mid
:
	lda gfx_y
	and #7
	asl
	asl
	asl
	ora #$c0
	ora gfx_addr_mid
	sta gfx_addr_mid

        lda gfx_x_data
        sam gfx_x_temp1

; restore and exit

        pla
        tay
        pla
        tax
        lda gfx_x_data
        plp
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

gfx_x:
        .res 1
gfx_x_row:
gfx_y:
        .res 1
gfx_x_bank:
        .res 1
gfx_x_data:
        .res 1
gfx_x_temp1:
gfx_addr_lo:
        .res 1
gfx_x_temp2:
gfx_addr_mid:
        .res 1
gfx_x_temp3:
gfx_addr_hi:
        .res 1
gfx_x_temp4:
        .res 1

