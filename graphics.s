	.include "drivecpu.i"

	.export gfx_cls
	.export gfx_drawlogo
	.export gfx_gotoxy
	.export gfx_puts
	.export gfx_putchar
	.export gfx_quickcls
	.export gfx_drawicon
	.export gfx_puthex


	.segment "GFXVECTORS"

gfx_cls:		jmp _gfx_cls
gfx_drawlogo:		jmp _gfx_drawlogo
gfx_gotoxy:		jmp _gfx_gotoxy
gfx_puts:		jmp _gfx_puts
gfx_putchar:		jmp _gfx_putchar
gfx_quickcls:		jmp _gfx_quickcls
gfx_drawicon:		jmp _gfx_drawicon
gfx_puthex:		jmp _gfx_puthex


	.zeropage

gfxptr:		.res 2
putsptr:	.res 2
cursy:		.res 1	; cursor y position
cursx:		.res 1	; cursor x position
ystop:		.res 1
char:		.res 1
tempx:		.res 1
tempy:		.res 1


	.bss

line:		.res 1


	.code

_gfx_quickcls:
	lda #0
	ldy #32
@nextline:
	gay
	ldx #79
:	gax
	gst
	dex
	bpl :-
	iny
	cpy #224
	bne @nextline
	rts


; clear screen
_gfx_cls:
	gab_odd
	jsr @doclr
	gab_even
@doclr:
	ldy #0
	tya
@nextline:
	gay
	ldx #79
:	gax
	gst
	dex
	bpl :-
	iny
	bne @nextline
	rts


_gfx_drawlogo:
	ldax bootlogo		; draw C-ONE logo
	stax gfxptr

	ldy #0
	sty line
@nextline:
	gay

	gab_odd

	ldx #31
	ldy #63
:	lda (gfxptr),y
	gax
	gst
	dey
	dex
	bpl :-

	gab_even

	ldx #31
	;ldy #31
:	lda (gfxptr),y
	gax
	gst
	dey
	dex
	bpl :-

	lda gfxptr
	clc
	adc #64
	sta gfxptr
	bcc :+
	inc gfxptr+1
:
	inc line
	ldy line
	cpy #24
	bne @nextline


	ldx #0
	ldy #4

	; fall through


; set cursor to x, y
_gfx_gotoxy:
	stx cursx
	sty cursy
	rts


_gfx_puts:
	stax putsptr
	ldy #0
:	lda (putsptr),y
	beq @done
	jsr gfx_putchar
	iny
	bne :-
@done:
	rts


_gfx_putchar:
	sta char
	stx tempx
	sty tempy
	cmp #$80
	bcs @gfxchar
	cmp #32
	bcs @nocontrol
	cmp #10
	beq @lf
	cmp #13
	beq @cr
	cmp #9
	beq @tab
@gfxchar:
	and #$7f
@nocontrol:
	jsr gfx_plotchar
	jsr gfx_nextchar
@return:
	ldy tempy
	ldx tempx
	lda char
	rts
@lf:
	inc cursy
	lda cursy
	cmp #32
	bne @return
	lda #0
	sta cursy
	beq @return
@cr:
	lda #0
	sta cursx
	beq @return
@tab:
	lda cursx
	and #7
	beq @return
	lda cursx
	ora #7
	clc
	adc #1
	sta cursx
	jmp @return


; advance to the next character
gfx_nextchar:
	inc cursx
	lda cursx
	cmp #80
	bcc @return
	lda #0
	sta cursx
	inc cursy
	lda cursy
	cmp #32
	bcc @return
	lda #0
	sta cursy
@return:
	rts


; plot character at current position
gfx_plotchar:
	ldx cursx
	gax
	asl
	asl
	bcs @upper

@lower:
	asl
	tax
	bcs @num
@sym:
	lda cursy
	asl
	asl
	asl
	tay
	clc
	adc #8
	sta ystop
:	gay
	lda font_sym,x
	gst
	inx
	iny
	cpy ystop
	bne :-
	rts

@num:
	lda cursy
	asl
	asl
	asl
	tay
	clc
	adc #8
	sta ystop
:	gay
	lda font_num,x
	gst
	inx
	iny
	cpy ystop
	bne :-
	rts

@upper:
	asl
	tax
	bcs @az
@AZ:
	lda cursy
	asl
	asl
	asl
	tay
	clc
	adc #8
	sta ystop
:	gay
	lda font_AZ,x
	gst
	inx
	iny
	cpy ystop
	bne :-
	rts

@az:
	lda cursy
	asl
	asl
	asl
	tay
	clc
	adc #8
	sta ystop
:	gay
	lda font_az,x
	gst
	inx
	iny
	cpy ystop
	bne :-
	rts


; draw 32x32 icon at cursor position
_gfx_drawicon:
	stax gfxptr

	lda cursx
	clc
	adc #4
	sta tempx

	lda cursy
	asl
	asl
	asl
	sta line
	tay
	clc
	adc #16
	sta tempy
@nextline:
	gay

	gab_even
	ldy #0
	ldx cursx
:	lda (gfxptr),y
	gax
	gst
	iny
	inx
	cpx tempx
	bne :-

	gab_odd
	ldy #4
	ldx cursx
:	lda (gfxptr),y
	gax
	gst
	iny
	inx
	cpx tempx
	bne :-

	lda gfxptr
	clc
	adc #8
	sta gfxptr
	bcc :+
	inc gfxptr+1
:
	inc line
	ldy line
	cpy tempy
	bne @nextline

	gab_even
	rts


_gfx_puthex:
	pha
	stx @xtemp
	lsr
	lsr
	lsr
	lsr
	tax
	lda hextoascii,x
	jsr _gfx_putchar
	pla
	and #$0f
	tax
	lda hextoascii,x
	ldx @xtemp
	jmp _gfx_putchar

	.bss

@xtemp:	.res 1


	.rodata

	.align 256
bootfont:
	.incbin "bootfont.bin"
font_sym	= bootfont
font_num	= bootfont + 256
font_AZ		= bootfont + 512
font_az		= bootfont + 768

bootlogo:
	.incbin "bootlogo.bin"

hextoascii:
	.byte "0123456789abcdef"
