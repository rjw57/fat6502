

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
; bits 4-7 unused, set to 0

	.macro csa
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


; --- Floppy ---

; Floppy control, all active low
; bit 0    direction
; bit 1    step
; bit 2    drv_sel_a
; bit 3    drv_sel_b
; bit 4    motor

	.macro flp
	.byte $0c
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

; load keyboard scancode. carry set if fifo is empty (and A invalid)
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
;
; gax => addr(9..2)
; gab(0) => addr(10)
; gay => addr(18..11)
; gab(5..1) => addr(23..19)

; set graphics cursor x position
	.macro gax
	.byte $02
	.endmacro

; set graphics cursor y position, bits 1..8
	.macro gay
	.byte $03
	.endmacro

; set graphics bank and bit 0 of cursor y position
	.macro gab
	.byte $07
	.endmacro

	.macro gab_even
	lda #$02
	gab
	.endmacro

	.macro gab_odd
	lda #$03
	gab
	.endmacro

; write to graphics ram
	.macro gst
	.byte $04
	.endmacro
