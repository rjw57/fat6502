	.include "drivecpu.i"


	.export bootmenu


	.import bootconfig
	.import entermenu

	.import cluster
	.import clusterbuf
	.import vol_dir_first
	.import vol_dir_next
	.import vol_read_clust
	.import vol_stat
	.import vol_isdesc
	.import vol_isrom
	.import vol_isfpgabin
	.import vol_isdrivebin
	.import vol_isflashbin
	.import vol_firstnamechar
	.import vol_endofdir

	.import stat_length
	.import stat_cluster

	.importzp clusterptr, ptr

	.import gfx_gotoxy
	.import gfx_putchar
	.import gfx_puts
	.import gfx_quickcls
	.import gfx_drawicon
	.import gfx_x


	.zeropage

descptr:		.res 2	; pointer to current descstr


	.bss

desclist:	.res (32+2+1)*10; list of descriptions
desc:		.res 10		; config present
desccluster:	.res 10*4	; start cluster of desc file
currdesc:	.res 1
numdescs:	.res 1		; number of found desc.txt's
desclen:	.res 10		; length of descriptions
descstr:	.res 2*10	; description string pointers
vbl:		.res 1		; vbl counter
seconds:	.res 1		; seconds counter
erased:		.res 1


	.code

bootmenu:
	jsr checkentry
	bcc :+			; just return if no descs are found
	rts
:	jsr readdescs
	jsr drawmenu
	lda #0
	sta currdesc
	jsr drawcursor
	jsr selectconfig
	lda currdesc		; convert to ascii number
	clc
	adc #$30
	sta bootconfig		; and store

	jmp gfx_quickcls	; clear screen


checkentry:
	ldx #9
	lda #0
:	sta desc,x
	dex
	bpl :-

	lda #0
	sta numdescs

	;jsr vol_dir_first	; already called in boot.s

@checkentry:
	jsr vol_endofdir	; check for end of dir
	beq @foundlast

	jsr vol_isdesc		; check if it's ?DESC.TXT
	bcs @next

	jsr vol_firstnamechar	; yes, grab first char
	sec			; assume it's a number
	sbc #$30
	bmi @next		; wtf, not a number
	cmp #10
	bcs @next		; also not a number
	sta currdesc
	tax
	dec desc,x		; flag it as found

	inc numdescs		; found one

	jsr vol_stat		; grab the start cluster
	lda currdesc
	asl
	asl
	tax
	ldy #0
:	lda stat_cluster,y	; save it in the array
	sta desccluster,x
	inx
	iny
	cpy #3
	bne :-

@next:
	jsr vol_dir_next	; find the next dir entry
	bcc @checkentry

@error:
	sec
	rts

@foundlast:
	lda numdescs		; did we find any?
	beq @error		; bummer
	clc
	rts


readdescs:
	ldax #desclist		; init pointer to desc
	stax descptr

	ldx #0
	stx currdesc
@checkdesc:
	lda #0
	sta desclen,x		; default length = 0
	lda desc,x		; check if present
	beq @next

	txa			; grab the cluster
	asl
	asl
	tax
	ldy #0
:	lda desccluster,x
	sta cluster,y
	inx
	iny
	cpy #4
	bne :-

	ldax #clusterbuf
	stax clusterptr
	jsr vol_read_clust	; read the first part of the file
	bcs @next		; this really shouldn't happen

	jsr copyline		; copy the first line of text
				; returns length in Y
	ldx currdesc
	tya
	sta desclen,x		; save length

	txa			; save string pointer
	asl
	tax
	lda descptr
	sta descstr,x
	lda descptr+1
	sta descstr+1,x

	iny			; skip 0 termination
	tya			; advance pointer
	clc
	adc descptr
	sta descptr
	bcc :+
	inc descptr+1
:

@next:
	inc currdesc
	ldx currdesc
	cpx #10
	bne @checkdesc

	clc
	rts


copyline:
	ldy #0
:	lda clusterbuf,y
	beq @eol		; wtf is a 0 doing here?
	cmp #13
	beq @eol
	cmp #10
	beq @eol
	sta (descptr),y		; not eol, copy char
	iny
	cpy #32			; max string len
	bne :-
@eol:
	lda #0
	sta (descptr),y
	rts


menuypos	= 7
menuxpos	= 26

drawmenu:
	jsr gfx_quickcls	; clear text screen

	ldx #menuxpos
	ldy #menuypos - 3
	jsr gfx_gotoxy
	ldax #msg_selectconfig
	jsr gfx_puts

	ldx #menuxpos
	ldy #menuypos + 12
	jsr gfx_gotoxy
	ldax #msg_updown
	jsr gfx_puts

	ldx #menuxpos - 1
	ldy #menuypos + 14
	jsr gfx_gotoxy
	ldax #msg_seconds
	jsr gfx_puts

	ldx #menuxpos - 8
	ldy #menuypos + 17
	jsr gfx_gotoxy
	ldax #msg_holddown
	jsr gfx_puts


	ldx #menuxpos - 4	; draw top
	ldy #menuypos - 1
	jsr gfx_gotoxy
	lda #7 + $80
	jsr gfx_putchar
	lda #12 + $80		; character to print
	ldx #35
:	jsr gfx_putchar
	dex
	bne :-
	lda #8 + $80
	jsr gfx_putchar

	ldx #menuxpos - 4	; draw bottom
	ldy #menuypos + 10
	jsr gfx_gotoxy
	lda #9 + $80
	jsr gfx_putchar
	lda #12 + $80
	ldx #35
:	jsr gfx_putchar
	dex
	bne :-
	lda #10 + $80
	jsr gfx_putchar

	lda #11	+ $80		; draw sides
	ldy #menuypos
:	ldx #menuxpos - 4
	jsr gfx_gotoxy
	jsr gfx_putchar
	ldx #menuxpos + 32
	jsr gfx_gotoxy
	jsr gfx_putchar
	iny
	cpy #menuypos + 10
	bne :-

	ldx #0
	stx currdesc
@printdesc:
	;lda desc,x
	;beq @next

	txa
	clc
	adc #menuypos
	tay
	ldx #menuxpos
	jsr gfx_gotoxy

	ldx currdesc
	lda desclen,x
	bne @print

	lda #'-'
	jsr gfx_putchar
	jmp @next

@print:
	txa
	asl
	tay
	lda descstr+1,y
	tax
	lda descstr,y
	jsr gfx_puts

@next:
	inc currdesc
	ldx currdesc
	cpx #10
	bne @printdesc

	rts


drawcursor:
	lda currdesc
	clc
	adc #menuypos
	tay
	ldx #menuxpos - 2
	jsr gfx_gotoxy
	lda #'>'
	jmp gfx_putchar


erasecursor:
	lda currdesc
	clc
	adc #menuypos
	tay
	ldx #menuxpos - 2
	jsr gfx_gotoxy
	lda #' '
	jmp gfx_putchar


; select a config with arrows and enter
selectconfig:
	lda #10
	sta seconds
	lda #50
	sta vbl
	lda #$ff
	sta erased

@checkkey:
	jsr waitvbl
	lka
	bcs @update

	ldx #$ff		; disable timer
	stx seconds

	cmp #$5a		; enter
	beq @enter

	cmp #$f0
	bne @make
@break:
:	lka			; eat next key
	bcs :-
	bcc @checkkey
@make:
	cmp #$e0		; cursor keys are extended codes
	bne @checkkey
:	lka			; eat next key
	bcs :-
	cmp #$f0
	beq @break

	cmp #$75
	beq @up
	cmp #$72
	beq @down

@update:
	dec vbl
	bne @checkkey
	lda #50
	sta vbl
	lda seconds
	bmi @erasemsg		; skip check if set to negative
	jsr printseconds
	dec seconds
	lda seconds
	bpl @checkkey
@return:
	rts			; timeout

@up:
	lda currdesc
	beq @checkkey
	jsr erasecursor
	dec currdesc
	jsr drawcursor
	jmp @checkkey

@down:
	lda currdesc
	cmp #9
	beq @checkkey
	jsr erasecursor
	inc currdesc
	jsr drawcursor
	jmp @checkkey

@enter:
	ldx currdesc
	lda desc,x
	beq @checkkey
	rts

@erasemsg:
	lda erased
	beq @checkkey

	ldx #menuxpos - 1
	ldy #menuypos + 14
	jsr gfx_gotoxy

	lda #' '
	ldx #31
:	jsr gfx_putchar
	dex
	bne :-
	jmp @checkkey


; wait a little while
waitvbl:
	ldy #33
	ldx #0
:	inx
	bne :-
	dey
	bne :-
	rts


printseconds:
	ldx #menuxpos + 20
	ldy #menuypos + 14
	jsr gfx_gotoxy

	lda seconds
	clc
	adc #$30
	tay
	ldx #' '
	cmp #$3a
	bcc :+
	ldx #'1'
	ldy #'0'
:	txa
	jsr gfx_putchar
	tya
	jmp gfx_putchar


	.rodata

msg_seconds:
	.byte "Default will boot in 10 seconds",0
msg_selectconfig:
	.byte "Select computer configuration",0
msg_updown:
	.byte $83, "/", $84," to select, Enter to start",0
msg_holddown:
	.byte "Hold down 0-9 to quick select and bypass menu",0
