; test program for the flash programming registers
; this code assumes that no dummy reads are done with lda addr,x and sta addr,x!!!


;rs232		= 1
ps2		= 1
;testscript	= 1


	.include "drivecpu.i"

	.export reseth

	.import timestamp

	.import __RELOC_SIZE__
	.import __RELOC_RUN__
	.import __RELOC_LOAD__

	.ifdef rs232
	.import debug_init
	.import debug_puts
	.import debug_puthex
	.import debug_crlf
	.import debug_putdigit
	.import debug_put
	.import debug_get
	.endif

	.ifdef ps2
	.import gfx_cls
	.import gfx_drawlogo
	.import gfx_gotoxy
	.import gfx_puts
	.import gfx_putchar
	.import gfx_quickcls
	.import gfx_drawicon
	.import gfx_puthex
	.endif

	.ifdef rs232
real_io_get	= debug_get     
	.endif

	.ifdef ps2
real_io_get	= kbd_get 
io_put		= gfx_putchar
io_puts		= gfx_puts
io_puthex	= gfx_puthex
io_putdigit	= gfx_putdigit
	.endif

	.ifdef testscript
io_get		= test_io_get
	.else
io_get		= real_io_get
	.endif


	.zeropage

addr:	.res 3
bank:	.res 1
byte:	.res 1
getctr:	.res 1


	.code

reseth:
	sei
	cld
	ldx #$ff
	txs

	lda #%00000110		; initalize ctl reg
	ctl

	.ifdef rs232
	jsr debug_init
	.else
	jsr gfx_cls
	.endif

	lda #0
	sta getctr
	sta bank
	lda #$01
	sta addr+2
	lda #$23
	sta addr+1
	lda #$45
	sta addr

	.ifdef ps2
	ldx #0
	ldy #0
	jsr gfx_gotoxy
	.endif
	ldax initmsg
	jsr io_puts

main:
	jsr print_status

	jsr io_get
	bcc @check
	jmp end

@check:
	cmp #'0'
	beq f_clear
	cmp #'1'
	beq f_inc
	cmp #'2'
	beq f_shift
	cmp #'b'
	beq f_bank
	cmp #'r'
	beq f_read
	cmp #'w'
	beq f_write

	jmp main


f_clear:
	bit flash_clear
	lda #0
	sta addr
	sta addr+1
	sta addr+2
	jmp main

f_inc:
	bit flash_inc
	inc addr
	bne main
	inc addr+1
	bne main
	inc addr+2
	jmp main

f_shift:
	bit flash_shift
	asl addr
	rol addr+1
	rol addr+2
	jmp main

f_bank:
	lda bank
	clc
	adc #1
	and #3
	sta bank
	jmp main

f_read:
	.ifdef ps2
	ldx #0
	ldy #10
	jsr gfx_gotoxy
	.endif
	ldax readmsg
	jsr io_puts
	jsr print_addr
	ldax equalsmsg
	jsr io_puts
	ldx bank
	lda flash_data,x
	jsr io_puthex
	.ifdef rs232
	jsr debug_crlf
	.else
	lda #' '
	jsr io_put
	.endif
	jmp main

f_write:
	.ifdef ps2
	ldx #0
	ldy #10
	jsr gfx_gotoxy
	.endif
	ldax writemsg
	jsr io_puts
	jsr print_addr
	ldax equalsmsg
	jsr io_puts
	.ifdef ps2
	lda #' '
	jsr io_put
	jsr io_put
	ldx #24
	ldy #10
	jsr gfx_gotoxy
	.endif
	jsr io_get
	jsr io_put
	jsr asciitohex
	asl
	asl
	asl
	asl
	sta byte
	jsr io_get
	jsr io_put
	.ifdef rs232
	jsr debug_crlf
	.endif
	jsr asciitohex
	ora byte
	ldx bank
	sta flash_data,x
	jmp main


end:
	.ifdef ps2
	ldx #0
	ldy #12
	jsr gfx_gotoxy
	.endif
	ldax endmsg
	jsr io_puts

	jmp *


print_status:
	.ifdef ps2
	ldx #0
	ldy #9
	jsr gfx_gotoxy
	.endif
	ldax statusmsg1
	jsr io_puts

	lda bank
	jsr io_putdigit

	ldax statusmsg2
	jsr io_puts

	.ifdef rs232
	jsr print_addr
	jmp debug_crlf
	.else
	jmp print_addr
	.endif


print_addr:
	lda addr+2
	and #1
	jsr io_putdigit

	lda addr+1
	jsr io_puthex

	lda addr
	jmp io_puthex


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


test_io_get:
	ldx getctr
	lda inputdata,x
	bne :+
	sec
	rts
:	inc getctr
	clc
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


gfx_putdigit:
	php
	pha
	clc
	adc #'0'
	jsr gfx_putchar
	pla
	plp
	rts
 

	.rodata

scantable:
	.byte 0
	.byte $45,$16,$1e,$26,$25,$2e,$36,$3d,$3e,$46
	.byte $1c,$32,$21,$23,$24,$2b
	.byte $2d,$1d
scantoasc:
	.byte 0,"0123456789"
	.byte "abcdef"
	.byte "rw"
exttable:
	.byte 0
exttoasc:
	.byte 0


inputdata:
	.byte "01221221221221221221221"
	.byte "waa"
	.byte "23"
	.byte "w55"
	.byte "21"
	.byte "wa0"
	.byte "bbb"
	.byte "0121212121212121212121212121212121"
	.byte "w00"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte "r"
	.byte 0

initmsg:
	.byte "C1 Flash Test",13,10
	.byte "0 - clear",13,10
	.byte "1 - increment",13,10
	.byte "2 - shift left",13,10
	.byte "b - select bank",13,10
	.byte "r - read byte",13,10
	.byte "w - write byte",13,10
	.byte 13,10,0

statusmsg1:
	.byte "* bank = ",0
statusmsg2:
	.byte "  addr = ",0

readmsg:
	.byte "* read address ",0

writemsg:
	.byte "* write address ",0

equalsmsg:
	.byte " = ",0

endmsg:
	.byte "-EOT-",13,10,0
