	.include "drivecpu.i"

	.export gfx_cls
	.export gfx_drawlogo
	.export gfx_gotoxy
	.export gfx_puts
	.export gfx_putchar


	.segment "GFXVECTORS"

gfx_cls:		jmp _gfx_cls
gfx_drawlogo:		jmp _gfx_drawlogo
gfx_gotoxy:		jmp _gfx_gotoxy
gfx_puts:		jmp _gfx_puts
gfx_putchar:		jmp _gfx_putchar


	.zeropage

gfxptr:		.res 2
putsptr:	.res 2
cursy:		.res 1	; cursor y position
cursx:		.res 1	; cursor x position
ystop:		.res 1
char:		.res 1
tempx:		.res 1
tempy:		.res 1


	.code

doclr:
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


; clear screen
_gfx_cls:
	gab_odd
	jsr doclr
	gab_even
	jsr doclr
	
	lda #0
	sta cursx
	sta cursy

	rts


_gfx_drawlogo:
	ldax logo1		; draw C-ONE logo
	stax gfxptr

	ldx #1
@nextcolumn:
	gax
	ldy #0
@nextline:
	gay
	lda (gfxptr),y
	gst
	iny
	cpy #24
	bne @nextline
	lda gfxptr
	clc
	adc #24
	sta gfxptr
	bcc :+
	inc gfxptr+1
:	inx
	cpx #4
	bne @nextcolumn

	ldx #5
	ldy #0
	jsr gfx_gotoxy
	ldax msg_cone1
	jsr gfx_puts

	ldx #5
	ldy #1
	jsr gfx_gotoxy
	ldax msg_cone2
	jsr gfx_puts

	ldx #5
	ldy #2
	jsr gfx_gotoxy
	ldax msg_cone3
	jsr gfx_puts

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
	jsr gfx_plotchar
	jsr gfx_nextchar
	ldy tempy
	ldx tempx
	lda char
	rts


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


	.rodata


msg_cone1:
	.byte "CCC     OOO NN  EEE",0
msg_cone2:
	.byte "C   --- O O N N EE ",0
msg_cone3:
	.byte "CCC     OOO N N EEE",0


	.align 256
bootfont:
	.incbin "bootfont.bin"
font_sym	= bootfont
font_num	= bootfont + 256
font_AZ		= bootfont + 512
font_az		= bootfont + 768


logo1:
	.byte %00000000
	.byte %00000001
	.byte %00000111
	.byte %00001110
	.byte %00011000
	.byte %00110000
	.byte %00110000
	.byte %01100000
	.byte %01100000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %11000000
	.byte %01100000
	.byte %01100000
	.byte %00110000
	.byte %00110000
	.byte %00011000
	.byte %00001110
	.byte %00000111
	.byte %00000001
	.byte %00000000

	.byte %01111110
	.byte %11111111
	.byte %10000001
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00000000
	.byte %00111111
	.byte %00111111
	.byte %00110000
	.byte %00110000
	.byte %00110011
	.byte %00110011
	.byte %00110011
	.byte %00110011
	.byte %00110011
	.byte %00110011
	.byte %00110011
	.byte %11110011
	.byte %11110011
	.byte %01110011

	.byte %00000000
	.byte %10000000
	.byte %11100000
	.byte %01110000
	.byte %00011000
	.byte %00001100
	.byte %00001100
	.byte %00000110
	.byte %00000110
	.byte %00000111
	.byte %11111111
	.byte %11111111
	.byte %00000000
	.byte %00000000
	.byte %11111111
	.byte %11111111
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %00000011
	.byte %11111111
	.byte %11111111
