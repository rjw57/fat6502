	.include "drivecpu.i"


	.export bar_init
	.export bar_done
	.export bar_update

	.export bar_max
	.export bar_curr

	.import gfx_gotoxy
	.import gfx_putchar


	.zeropage

n:		.res 7		; div scatchpad
carry:		.res 1		; div carry


	.bss

bar_max:	.res 4		; max value
bar_curr:	.res 4		; current value
lastpos:	.res 1		; last character printed


progbarline	= 24


	.code

bar_init:
	lda #0
	sta lastpos
	ldx #8
	ldy #progbarline
	jsr gfx_gotoxy
	lda #$82		; 50% dither
	ldx #64
:	jsr gfx_putchar
	dex
	bne :-
	rts


bar_done:
	ldx #8
	ldy #progbarline
	jsr gfx_gotoxy
	lda #' '
	ldx #64
:	jsr gfx_putchar
	dex
	bne :-
	rts


bar_update:
	jsr calc		; 64 * curr / max
	beq @done
	cmp lastpos
	beq @done
	bcc @done

	pha
	lda lastpos
	clc
	adc #8
	tax
	ldy #progbarline
	jsr gfx_gotoxy
	pla
	tax
	sec
	sbc lastpos
	stx lastpos
	tax
	lda #$81
:	jsr gfx_putchar
	dex
	bne :-
@done:
	rts


; a = curr / (max / 64)
calc:
	lda bar_curr		
	sta n + 4
	lda bar_curr + 1
	sta n + 5
	lda bar_curr + 2
	sta n + 2
	lda bar_curr + 3
	sta n + 3

	lda bar_max	; max / 256 ...
	asl		; ... * 2 ...
	lda bar_max + 1
	rol
	sta n
	lda bar_max + 2
	rol
	sta n + 1
	lda bar_max	; ... * 2
	asl
	asl
	rol n
	rol n + 1


; 32/16 = 16.16 routine by Garth Wilson

	sec		; Detect overflow or /0 condition.
	lda n+2		; Divisor must be more than high cell of dividend.  To
	sbc n		; find out, subtract divisor from high cell of dividend;
	lda n+3		; if carry flag is still set at the end, the divisor was
	sbc n+1		; not big enough to avoid overflow. This also takes care
	bcs @oflo	; of any /0 condition.	Branch if overflow or /0 error.
			; We will loop 16 times; but since we shift the dividend
	ldx #17		; over at the same time as shifting the answer in, the
			; operation must start AND finish with a shift of the
			; low cell of the dividend (which ends up holding the
			; quotient), so we start with 17 (11H) in X.
@loop:
	rol n+4		; Move low cell of dividend left one bit, also shifting
	rol n+5		; answer in. The 1st rotation brings in a 0, which later
			; gets pushed off the other end in the last rotation.
	dex
	beq @end	; Branch to the end if finished.

	rol n+2		; Shift high cell of dividend left one bit, also
	rol n+3		; shifting next bit in from high bit of low cell.
	lda #0
	sta carry	; Zero old bits of carry so subtraction works right.
	rol carry	; Store old high bit of dividend in carry.  (For STZ
			; one line up, MMOS 6502 will need lda #0, sta carry.)
	sec		; See if divisor will fit into high 17 bits of dividend
	lda n+2		; by subtracting and then looking at carry flag.
	sbc n		; First do low byte.
	sta n+6		; Save difference low byte until we know if we need it.
	lda n+3		;
	sbc n+1		; Then do high byte.
	tay 		; Save difference high byte until we know if we need it.
	lda carry	; Bit 0 of carry serves as 17th bit.
	sbc #0		; Complete the subtraction by doing the 17th bit before
	bcc @loop	; determining if the divisor fit into the high 17 bits
			; of the dividend.  If so, the carry flag remains set.
	lda n+6		; If divisor fit into dividend high 17 bits, update
	sta n+2		; dividend high cell to what it would be after
	sty n+3		; subtraction.
	bcs @loop	; Always branch.  NMOS 6502 could use bcs here.
@oflo:
	lda #$ff	; If overflow occurred, put FF
	sta n+2		; in remainder low byte
	sta n+3		; and high byte,
	sta n+4		; and in quotient low byte
	sta n+5		; and high byte.
@end:
	lda n+4
	rts
