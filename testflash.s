; test program for the flash programming registers
; this code assumes that no dummy reads are done with lda addr,x and sta addr,x!!!


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
;	.import debug_get
debug_get	= test_debug_get


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
flash_clear15	= $3f62
flash_shift	= $3f66
flash_inc	= $3f68
flash_data	= $3f6c


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

	jsr debug_init

	lda #0
	sta getctr
	sta bank
	lda #$01
	sta addr+2
	lda #$23
	sta addr+1
	lda #$45
	sta addr

	ldax initmsg
	jsr debug_puts

main:
	jsr print_status

	jsr debug_get
	bcc @check
	jmp end

@check:
	cmp #'0'
	beq f_clear
	cmp #'1'
	beq f_inc
	cmp #'2'
	beq f_shift
	cmp #'3'
	beq f_clear15
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

f_clear15:
	bit flash_clear15
	lda addr+1
	and #$7f
	sta addr+1
	jmp main

f_bank:
	lda bank
	clc
	adc #1
	and #3
	sta bank
	jmp main

f_read:
	ldax readmsg
	jsr debug_puts
	jsr print_addr
	ldax equalsmsg
	jsr debug_puts
	ldx bank
	lda flash_data,x
	jsr debug_puthex
	jsr debug_crlf
	jmp main

f_write:
	ldax writemsg
	jsr debug_puts
	jsr print_addr
	ldax equalsmsg
	jsr debug_puts
	jsr debug_get
	jsr debug_put
	jsr asciitohex
	asl
	asl
	asl
	asl
	sta byte
	jsr debug_get
	jsr debug_put
	jsr debug_crlf
	jsr asciitohex
	ora byte
	ldx bank
	sta flash_data,x
	jmp main


end:
	ldax endmsg
	jsr debug_puts

	jmp *


print_status:
	ldax statusmsg1
	jsr debug_puts

	lda bank
	jsr debug_putdigit

	ldax statusmsg2
	jsr debug_puts

	jsr print_addr

	jmp debug_crlf


print_addr:
	lda addr+2
	and #1
	jsr debug_putdigit

	lda addr+1
	jsr debug_puthex

	lda addr
	jmp debug_puthex


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


test_debug_get:
	ldx getctr
	lda inputdata,x
	bne :+
	sec
	rts
:	inc getctr
	clc
	rts


	.rodata

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
	.byte "3 - clear bit 15",13,10
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
