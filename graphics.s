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

gfxptr:		.res 3
srcptr:		.res 2
putsptr:	.res 2
cursptr:	.res 3
cursy:		.res 1	; cursor y position
cursx:		.res 1	; cursor x position
ystop:		.res 1
char:		.res 1
tempx:		.res 1
tempy:		.res 1
baseaddr:	.res 1


	.bss

line:		.res 1


bgcolor = 4		; blue
fgcolor = 10		; yellow


	.code


; clear screen below logo
_gfx_quickcls:
	lda #$0b
	sta gfxptr + 2

	ldx #7
@next:
	ldy #210
	lda rowmask,x
	ora #$01
	sta gfxptr + 1
	lda #$40
	sta gfxptr
	lda #0
@clear:
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	sam (gfxptr)
	inc gfxptr
	bne :+
	inc gfxptr + 1
:	dey
	bne @clear

	dex
	bpl @next

	rts


; clear screen
_gfx_cls:
	lda #%10010010		; set hires mode
	zout $7f

	lda #$0c		; reset screenbase, lo
	zout $bc
	lda #$30
	zout $bd

	lda #$0d		; hi
	zout $bc
	lda #$0
	zout $bd

	lda #%00000000		; select pen 0
	zout $7f
	lda #$40 | bgcolor	; set color
	zout $7f

	lda #%00000001		; select pen 1
	zout $7f
	lda #$40 | fgcolor	; set color
	zout $7f

	lda #$0b
	sta gfxptr + 2
	lda #$c0
	sta gfxptr + 1
	lda #0
	sta gfxptr

@clear:
	sam (gfxptr)
	inc gfxptr
	bne @clear
	inc gfxptr + 1
	bne @clear

	rts


_gfx_drawlogo:
	ldax #bootlogo		; draw C-ONE logo
	stax srcptr

	lda #$00
	sta gfxptr
	lda #$c0
	sta gfxptr + 1
	lda #$0b
	sta gfxptr + 2

	lda #3
	sta line
@nextline:
	ldx #32
@nextcol:
	ldy #7
:	lda rowmask,y
	sta gfxptr + 1
	lda (srcptr),y
	sam gfxptr
	dey
	bpl :-

	lda srcptr
	clc
	adc #8
	sta srcptr
	bne :+
	inc srcptr + 1
:
	inc gfxptr
	bne :+
	inc gfxptr + 1
:
	dex
	bne @nextcol

	lda gfxptr
	clc
	adc #(80 - 32)
	sta gfxptr
	; bcc :+
	; inc gfxptr + 1

	dec line
	bne @nextline

	ldx #0
	ldy #4

	; fall through


; set cursor to x, y
_gfx_gotoxy:
	pha

	stx cursx
	sty cursy

	lda #$0b
	sta cursptr + 2
	lda #0
	sta cursptr + 1

	tya
	asl
	asl
	;clc
	adc cursy
	asl
	rol cursptr + 1
	asl
	rol cursptr + 1
	asl
	rol cursptr + 1
	asl
	rol cursptr + 1
	;clc
	adc cursx
	sta cursptr
	bcc :+
	inc cursptr + 1
:	lda #$c8
	ora cursptr + 1
	sta cursptr + 1

	pla
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
	lda cursptr
	clc
	adc #80
	sta cursptr
	bcc :+
	inc cursptr + 1
:	jmp @return
@cr:
	lda cursptr
	sec
	sbc cursx
	sta cursptr
	bcs :+
	dec cursptr + 1
:	lda #0
	sta cursx
	beq @return
@tab:
	lda cursx
	ora #7
	clc
	adc #1
	tax
	sec
	sbc cursx
	clc
	adc cursptr
	sta cursptr
	bcc :+
	inc cursptr + 1
:	stx cursx
	jmp @return


; advance to the next character
gfx_nextchar:
	inc cursptr
	bne :+
	inc cursptr + 1
:	inc cursx
	lda cursx
	cmp #80
	bcc @return
	lda #0
	sta cursx
	inc cursy
	lda cursy
	cmp #25
	bcc @return
	lda #0
	sta cursy
@return:
	rts


; plot character at current position
gfx_plotchar:
	pha

	lda cursptr
	sta gfxptr
	lda cursptr + 1
	and #7
	sta baseaddr
	lda cursptr + 2
	sta gfxptr + 2

	ldy #0

	pla
	asl
	asl
	bcs @upper
@lower:
	asl
	tax
	bcs @num
@sym:
:	lda rowmask,y
	ora baseaddr
	sta gfxptr + 1
	lda font_sym,x
	sam gfxptr
	inx
	iny
	cpy #8
	bne :-
	rts
@num:
:	lda rowmask,y
	ora baseaddr
	sta gfxptr + 1
	lda font_num,x
	sam gfxptr
	inx
	iny
	cpy #8
	bne :-
	rts
@upper:
	asl
	tax
	bcs @az
@AZ:
:	lda rowmask,y
	ora baseaddr
	sta gfxptr + 1
	lda font_AZ,x
	sam gfxptr
	inx
	iny
	cpy #8
	bne :-
	rts
@az:
:	lda rowmask,y
	ora baseaddr
	sta gfxptr + 1
	lda font_az,x
	sam gfxptr
	inx
	iny
	cpy #8
	bne :-
	rts


; draw 32x32 icon at cursor position
_gfx_drawicon:
	stax srcptr

	lda cursptr
	sta gfxptr
	lda cursptr + 1
	and #7
	sta baseaddr
	lda cursptr + 2
	sta gfxptr + 2

	lda #2
	sta line
@nextline:
	ldx #4
@nextcol:
	ldy #7
:	lda rowmask,y
	ora baseaddr
	sta gfxptr + 1
	lda (srcptr),y
	sam gfxptr
	dey
	bpl :-

	lda srcptr
	clc
	adc #8
	sta srcptr
	bne :+
	inc srcptr + 1
:
	inc gfxptr
	bne :+
	inc gfxptr + 1
:
	dex
	bne @nextcol

	lda gfxptr
	clc
	adc #(80 - 4)
	sta gfxptr
	; bcc :+
	; inc gfxptr + 1

	dec line
	bne @nextline

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
rowmask:
	.byte $c0, $c8, $d0, $d8, $e0, $e8, $f0, $f8
