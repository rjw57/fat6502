	.include "drivecpu.i"

	.export gfx_cls
	.export gfx_drawlogo
	.export gfx_gotoxy
	.export gfx_puts
	.export gfx_putchar
	.export gfx_quickcls
	.export gfx_drawicon
	.export gfx_puthex
	.export gfx_x


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
putsptr:	.res 2
cursy:		.res 1	; cursor y position
cursx:		.res 1	; cursor x position
ystop:		.res 1
char:		.res 1
tempx:		.res 1
tempy:		.res 1


	.bss

line:		.res 1


bgcolor = 4		; blue
fgcolor = 10		; yellow


	.code

; 07-sept-2004 add CPC gfx hack

; entry point and parameter storage for CPC gfx hack

gfx_x:
        .res 1
gfx_x_row:
gfx_y:
        .res 1
gfx_x_bank:
        .res 1
gfx_x_data:
        .res 1

; temporary storage

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

; gst routine here... no separate label

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


; clear screen below logo
_gfx_quickcls:
	lda #$0b
	sta gfxptr + 2

	ldx #7
@next:
	ldy #210
	lda rowsel,x
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
	stax gfxptr

	ldy #0
	sty line
@nextline:
	gay

	ldx #31
	ldy #63
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

	ldy #0
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
rowsel:
	.byte $c0, $c8, $d0, $d8, $e0, $e8, $f0, $f8
