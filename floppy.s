	.include "drivecpu.i"

	.export floppy_init
	.export floppy_read_sector
	.exportzp devtype_floppy


	.import debug_put
	.import debug_puts
	.import debug_crlf


	.bss

flp_dir		= %11111110	; bit 0    direction
flp_step	= %11111101	; bit 1    step
flp_drive_a	= %11111011	; bit 2    drv_sel_a
flp_drive_b	= %11110111	; bit 3    drv_sel_b
flp_motor	= %11101111	; bit 4    motor
flp_none	= %11111111

devtype_floppy	= $03

currdrive:	.res 1	; current drive
cnt:		.res 1	; step counter


	.code

; initialize floppy, 0 or 1 in A
floppy_init:
	sec
	rts

	.if 0

	pha
	ldax msg_init
	jsr debug_puts
	pla
	pha
	clc
	adc #'A'
	jsr debug_put
	jsr debug_crlf
	pla

	lsr			; A -> C
	lda #flp_drive_a	; assume drive a
	bcc :+
	eor #flp_drive_b	; change
:	sta currdrive		; save mask


	ldax msg_motoron
	jsr debug_puts


	lda currdrive		; turn on motor
	and #flp_motor
	flp

	jsr flp_delay		; wait for motor


	ldax msg_step1
	jsr debug_puts


	lda #80
	sta cnt

@step1:
	lda currdrive		; strobe step
	and #flp_motor
	and #flp_step
	;and #flp_dir		; one direction direction
	flp

	jsr flp_delay		; wait for step

	lda currdrive		; release step
	and #flp_motor
	flp

	jsr flp_delay		; wait

	lda #'.'
	jsr debug_put

	dec cnt
	bne @step1


	ldax msg_step0
	jsr debug_puts


	lda #80
	sta cnt

@step0:
	lda currdrive		; strobe step
	and #flp_motor
	and #flp_step
	and #flp_dir		; other direction
	flp

	jsr flp_delay		; wait for step

	lda currdrive		; release step
	and #flp_motor
	flp

	jsr flp_delay		; wait

	lda #'.'
	jsr debug_put

	dec cnt
	bne @step0


	lda #flp_none		; release
	flp

	ldax msg_motoroff
	jsr debug_puts

	rts
	.endif



floppy_read_sector:
	sec
	rts


; this should take something like 656640 cycles =~ 0.3 secs
flp_delay:
	ldy #0
	ldx #0
:	nop
	bit $ea
	inx
	bne :-
	iny
	bne :-
	rts


	.rodata

msg_init:
	.byte "initializing floppy ",0
msg_motoron:
	.byte "floppy motor on",13,10,0
msg_motoroff:
	.byte "floppy motor off",13,10,0
msg_step0:
	.byte "stepping with direction 0",13,10,0
msg_step1:
	.byte "stepping with direction 1",13,10,0
