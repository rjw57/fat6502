

; CPU speed in MHz
cpuspeed	= 2


; C=1 custom opcode macros


; --- Debugging ---

; Pause and display hex number
; Usage: trc $01

	.macro trc id
	;.ifdef DEBUG
	.byte $ff, id
	;.endif
	.endmacro

; --- IDE ---
	
; IDE register select
; bit 0-2  A0-A2
; bit 3    IDE channel
; bit 4    CPU DMA control line
; bit 5    strobe 0 to erase FPGA, set to 1
; bit 6    CPU RESET control line
; bit 7    unused, set to 0

	.macro csa
	ora #%01100000		; keep reset and erase line high
	.byte $5a
	.endmacro

	.macro csa_unsafe
	.byte $5a
	.endmacro

; erase FPGA
	.macro clf
	lda #%01000000
	.byte $5a
	lda #%01100000
	.byte $5a
	.endmacro

; IDE load from register
; LSB in A, MSB in X
; flags are not affected!

	.macro ild
	.byte $3a
	.endmacro

; IDE store to register
; LSB in A, MSB in X
; flags are not affected!

	.macro ist
	.byte $1a
	.endmacro


; --- System config ---

; system ram memory bank select
	.macro sab
	.byte $52
	.endmacro

; system ram memory address msb
	.macro sau
	.byte $72
	.endmacro

; system ram memory address lsb
	.macro sal
	.byte $92
	.endmacro

; read from system ram pointed to by sab/sau/sal
	.macro mld
	.byte $d2
	.endmacro

; write to system ram pointed to by sab/sau/sal
	.macro mst
	.byte $f2
	.endmacro

; store accumulator in FPGA config
	.macro saf
	.byte $12
	.endmacro


; --- Keyboard ---

; load keyboard scancode
	.macro lka
	.byte $32
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

; util
	.macro ldax address
	lda #<address
	ldx #>address
	.endmacro

	.macro stax dest
	sta dest
	stx dest+1
	.endmacro


; --- Graphics ---

; set graphics cursor x position
	.macro gax
	.byte $02
	.endmacro

; set graphics cursor y position, bits 1..8
	.macro gay
	.byte $03
	.endmacro

; set graphics cursor y position, bit 0
	.macro gab
	.byte $07
	.endmacro

; write to graphics ram
	.macro gst
	.byte $04
	.endmacro
