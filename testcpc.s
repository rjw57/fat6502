	.include "drivecpu.i"

	.export reseth
	.export warmstart

	.importzp ptr

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_puthex
	.import debug_crlf


	.bss

lastkey:	.res 1


	.segment "VOLZP" : zeropage
	.segment "DEVZP" : zeropage
	.segment "VOLBSS"
	.segment "DEVBSS"
	.segment "VOLVECTORS"
	.segment "DEVVECTORS"
	.segment "CTLVECTORS"
	.segment "DBGVECTORS"
	.segment "GFXVECTORS"


	.segment "RELOC"

; this is a dummy segment just to suppress an ld65 warning


	.bss

gfxptr:	.res 3


	.macro sam ptradr
	.byte $f2, <ptradr, >ptradr
	.endmacro


	.code

warmstart:
reseth:
	ldx #0
:	lda msg,x
	beq @done
	jsr putchar
	inx
	bne :-

@done:
	lda #$00
	sta gfxptr
	lda #$c0
	sta gfxptr + 1
	lda #$0b
	sta gfxptr + 2

	lda #$55
	sam gfxptr

	rti


putchar:
	.byte 0
	.byte 9
	.byte $c0
	rts

msg:
	.byte "Hello, world!", 13, 10, 0


	lda #$00
	sta gfxptr
	lda #$c0
	sta gfxptr + 1
	lda #$0b
	sta gfxptr + 2

	ldx #$c0
	stx gfxptr + 1
	lda #$ff
	sam gfxptr

	ldx #$c8
	stx gfxptr + 1
	lda #$00
	sam gfxptr

	ldx #$d0
	stx gfxptr + 1
	lda #$ff
	sam gfxptr

	ldx #$d8
	stx gfxptr + 1
	lda #$00
	sam gfxptr

	ldx #$e0
	stx gfxptr + 1
	lda #$ff
	sam gfxptr

	ldx #$e8
	stx gfxptr + 1
	lda #$00
	sam gfxptr

	ldx #$f0
	stx gfxptr + 1
	lda #$ff
	sam gfxptr

	ldx #$f8
	stx gfxptr + 1
	lda #$00
	sam gfxptr

	rts

	jsr debug_init

	ldax msg_kbdinit
	jsr debug_puts

loop:
	lda $3d04
	jsr debug_puthex
	lda $3d05
	jsr debug_puthex
	jsr debug_crlf
	jmp loop


	.rodata

msg_kbdinit:
	.byte "keyboard test, hammer away",13,10,0
