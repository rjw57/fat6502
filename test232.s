	.include "drivecpu.i"

	.export reseth
	
	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_put
	.import debug_puthex


	.bss

lastkey:	.res 1
counter:	.res 1


	.code

reseth:
	jsr debug_init

@helloworld:
	lda #<hello
	ldx #>hello
	jsr debug_puts

	lda #10
	sta counter
@next:
	lka
	jsr debug_puthex
	lda #13
	jsr debug_put
	lda #10
	jsr debug_put
	dec counter
	bne @next

	lda #<presskeys
	ldx #>presskeys
	jsr debug_puts

	lda #0
	sta lastkey

@waitkey:
	lka
	cmp lastkey
	beq @waitkey
	sta lastkey
	jsr debug_puthex
	lda #13
	jsr debug_put
	lda #10
	jsr debug_put
	jmp @waitkey


hello:
	.byte "Hello, world!",13,10
	.byte "10 first bytes in the kbd fifo:",13,10
	.byte 0

presskeys:
	.byte 13,10
	.byte "Press keys on the kbd now please:",13,10
	.byte 0
