; CPU speed in MHz
cpuspeed	= 2


; --- Flash ROM ---

flash_clear	= $3f60
flash_shift	= $3f66
flash_inc	= $3f68
flash_data	= $3f6c


; --- RS-232 ---

A16550BASE	= $3f20


; --- Debugging ---

; Pause and display hex number
; Usage: trc $01

	.macro trc id
	;.ifdef DEBUG
	.byte $ff, id
	;.endif
	.endmacro

; --- I/O ---

; IDE register select
; bit 0-2  A0-A2
; bit 3    IDE channel
; bits 4-7 unused, set to 0

	.macro csa
	.byte $5a
	.endmacro

; I/O register select
; LSB in A, MSB in X

	.macro sca
	.byte $7a
	.endmacro

; Load from I/O bus
; LSB in A, MSB in X
; flags are not affected!

	.macro ild
	.byte $3a
	.endmacro

; Store to I/O bus
; LSB in A, MSB in X

	.macro ist
	.byte $1a
	.endmacro

; convenience

	.macro ldio ioaddr
	ldx #>ioaddr
	lda #<ioaddr
	sca
	ild
	.endmacro

	.macro stio ioaddr
	pha
	txa
	pha
	ldx #>ioaddr
	lda #<ioaddr
	sca
	pla
	tax
	pla
	ist
	.endmacro

; Load from Z80 I/O bus

	.macro zin port
	.byte $f3, <port
	.endmacro

; Store to Z80 I/O bus

	.macro zout port
	.byte $e3, <port
	.endmacro


; --- System config ---

; System control
; bit 0    CPU DMA control line, active low
; bit 1    erase FPGA, strobe low
; bit 2    CPU RESET control line, active low
; bits 3-7 unused, set to 0

	.macro ctl
	.byte $0b
	.endmacro


; load accumulator indirect from memory
	.macro lam ptraddr
	.byte $d2, <ptraddr, >ptraddr
	.endmacro

; store accumulator indirect from memory
	.macro sam ptraddr
	.byte $f2, <ptraddr, >ptraddr
	.endmacro

; store accumulator in FPGA config
	.macro saf
	.byte $12
	.endmacro


; --- Keyboard ---

; load keyboard scancode
; carry clear = valid key, set = invalid data in a
; overflow clear = normal key, set = extended key
; negative clear = make code, set = break code

	.macro lka
	.byte $32
	.endmacro


; --- misc ---
	.macro ldax arg
	.if (.match (.left (1, {arg}), #))	; immediate mode
	lda #<(.right (.tcount ({arg})-1, {arg}))
	ldx #>(.right (.tcount ({arg})-1, {arg}))
	.else					; assume absolute or zero page
	lda arg
	ldx 1 + (arg)
	.endif
	.endmacro

	.macro stax dest
	sta dest
	stx dest+1
	.endmacro


; --- Graphics ---
;
; gax => addr(9..2)
; gab(0) => addr(10)
; gay => addr(18..11)
; gab(5..1) => addr(23..19)

; 7-sept-2004 macros for CPC gfx hack:
; add .import gfx_x or they won't work

; set graphics cursor x position
        .macro gax
;       .byte $02
        stx gfx_x       ;!!!!!!!
	;stx $3f00
        .endmacro

; set graphics cursor y position, bits 1..8
        .macro gay
;       .byte $03
        sty gfx_x+1     ;!!!!!!!
	;sty $3f01
        .endmacro

; write to graphics ram
        .macro gst
;       .byte $04
        jsr gfx_x+8 ;didn't want to export another label
        .endmacro


; --- RS-232 Debugging ---

; print a string
	.macro dputs string
	php
	pha
	txa
	pha
	lda #<string
	ldx #>string
	jsr debug_puts
	pla
	tax
	pla
	plp
	.endmacro

; print a number in A
	.macro dputnum
	php
	pha
	jsr debug_puthex
	pla
	plp
	.endmacro

; print a digit in A
	.macro dputdigit
	php
	pha
	jsr debug_putdigit
	pla
	plp
	.endmacro

; print a character in A
	.macro dputc
	php
	pha
	jsr debug_put
	pla
	plp
	.endmacro

; print cr+lf
	.macro dputcrlf
	php
	pha
	jsr debug_crlf
	pla
	plp
	.endmacro

; print 32-bit number
	.macro dputnum32 address
	php
	pha
	lda address+3
	jsr debug_puthex
	lda address+2
	jsr debug_puthex
	lda address+1
	jsr debug_puthex
	lda address
	jsr debug_puthex
	pla
	plp
	.endmacro
