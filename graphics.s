	.include "drivecpu.i"

	.export gfx_cls
	.export gfx_drawlogo
	.export gfx_gotoxy
	.export gfx_puts
	.export gfx_putchar


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
gfx_cls:
	gab_odd
	jsr doclr
	gab_even
	jsr doclr
	
	lda #0
	sta cursx
	sta cursy

	rts


gfx_drawlogo:
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
	ldy #0

	; fall through


; set cursor to x, y
gfx_gotoxy:
	stx cursx
	sty cursy
	rts


gfx_puts:
	stax putsptr
	ldy #0
:	lda (putsptr),y
	beq @done
	jsr gfx_putchar
	iny
	bne :-
@done:
	rts


gfx_putchar:
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
	and #$3f		; limit to 64 chars for now
	asl
	asl			; fixme
	asl
	tax
	bcs numbers

letters:
	lda cursy
	asl
	asl
	asl
	tay
	clc
	adc #8
	sta ystop
@next:
	gay
	lda font_AZ,x
	gst
	inx
	iny
	cpy ystop
	bne @next
	rts

numbers:
	lda cursy
	asl
	asl
	asl
	tay
	clc
	adc #8
	sta ystop
@next:
	gay
	lda font_num,x
	gst
	inx
	iny
	cpy ystop
	bne @next
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
font_num	= bootfont + 256
font_AZ		= bootfont
font_az		= bootfont + 512
font_symbol	= bootfont + 768


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
