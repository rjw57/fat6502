;----------------------------------------------------------------------------------
; silver surfer code based on groepaz cc65 code
;----------------------------------------------------------------------------------

	.include "drivecpu.i"


	.export debug_init
	.export debug_done
	.export debug_puts
	.export debug_get
	.export debug_put
	.export debug_puthex
	.export debug_putdigit
	.export debug_crlf


	.segment "DBGVECTORS"

debug_init:		jmp _debug_init
debug_done:		jmp _debug_done
debug_puts:		jmp _debug_puts
debug_get:		jmp _debug_get
debug_put:		jmp _debug_put
debug_puthex:		jmp _debug_puthex
debug_putdigit:		jmp _debug_putdigit
debug_crlf:		jmp _debug_crlf


;Tobix was here
fifo_rxd	= 0	; (r)
fifo_txd	= 0	; (w)
fifo_dll	= 0
fifo_dlm	= 1
fifo_ier	= 1
fifo_fcr	= 2	; (w)
fifo_iir	= 2	; (r)
fifo_lcr	= 3
fifo_mcr	= 4
fifo_lsr	= 5
fifo_msr	= 6	; (r)
fifo_scratch	= 7	; (r/w)


	.zeropage

debug_ptr:	.res 2
sspresent:	.res 1		; $80 for ss present, $00 for no ss


	.rodata

debug_baudrates:

	.word	(7372800 / (      50 * 16))	; 0
	.word	(7372800 / (     110 * 16))	; 1
	.word	(7372800 / (     269 *  8))	; 2
	.word	(7372800 / (     300 * 16))	; 3
	.word	(7372800 / (     600 * 16))	; 4
	.word	(7372800 / (    1200 * 16))	; 5
	.word	(7372800 / (    2400 * 16))	; 6
	.word	(7372800 / (    4800 * 16))	; 7
	.word	(7372800 / (    9600 * 16))	; 8
	.word	(7372800 / (   19200 * 16))	; 9
	.word	(7372800 / (   38400 * 16))	; a
	.word	(7372800 / (   57600 * 16))	; b
	.word	(7372800 / (  115200 * 16))	; c
	.word	(7372800 / (  230400 * 16))	; d


baud_50		= 0
baud_110	= 1
baud_134	= 2
baud_300	= 3
baud_600	= 4
baud_1200	= 5
baud_2400	= 6
baud_4800	= 7
baud_9600	= 8
baud_19200	= 9
baud_38400	= 10
baud_57600	= 11
baud_115200	= 12
baud_230400	= 13


	.code

_debug_init:
;	lda #$55
;	sta fifo_scratch
;Tobix was here
	stx xtemp
	ldx #$f2   ;select Silversurfer
	lda #fifo_scratch
	sca			; set A[4..0] and Csel[3..0]
	lda #$55
	ist
	; set baudrate
	lda #baud_38400
	jsr debug_setbaud

;	lda fifo_scratch
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_scratch
	sca			; set A[4..0] and Csel[3..0]
	ild			; read MB[7..0]
	cmp #$55
	bne @noss

	lda #$80		; we found a silver surfer
	sta sspresent

	; disable nmi's from ssurfer
;	lda #0
;	sta fifo_ier
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_ier
	sca			; set A[4..0] and Csel[3..0]
	lda #0
	ist

	; activate dtr
;	lda #1
;	sta fifo_mcr
	ldx #$f2   ;select Silversurfer
	lda #fifo_mcr
	sca			; set A[4..0] and Csel[3..0]
	lda #1
	ist

	ldx #0
	ldy #0
@waitrecv:			; check if receiver is ready
;	lda fifo_msr
	ldx #$f2   ;select Silversurfer
	lda #fifo_msr
	sca			; set A[4..0] and Csel[3..0]
	ild			; read MB[7..0]
	and #%00010000
	bne @ready
	inx
	bne @waitrecv
	iny
	bne @waitrecv
;	beq @noss		; timeout
@noss:
	ldx #$ff		;deselcet all CEs
	sca			;very importend for the other stuff
	lda #0			; no silver surfer found
	sta sspresent
	ldx xtemp
	clc
	rts

@ready:
	ldx #$ff		;deselcet all CEs
	sca			;very importend for the other stuff
	ldax @initstr
	jsr debug_puts
	ldx xtemp
	clc
	rts


@initstr:
	.byte 13,10,"C-ONE debug init",13,10,0


_debug_puts:
	bit sspresent
	bpl @done

	sta debug_ptr
	stx debug_ptr+1
	ldy #0
@print:
	lda (debug_ptr),y
	beq @done
	jsr debug_put
	iny
	bne @print
@done:	rts


_debug_done:
	; disable nmi's from ssurfer
;	lda #0
;	sta fifo_ier
;Tobix was here
	stx xtemp
	ldx #$f2   ;select Silversurfer
	lda #fifo_ier
	sca			; set A[4..0] and Csel[3..0]
	lda #0
	ist
	; deactivate dtr
;	sta fifo_mcr
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_mcr
	sca			; set A[4..0] and Csel[3..0]
	lda #0
	ist

	ldx #$ff		;deselcet all CEs
	sca			;very importend for the other stuff
	lda #0			; no more rs-232
	sta sspresent

	ldx xtemp
	clc
	rts


debug_setbaud:
	; reset fifo
;	ldx #%10000111
;	stx fifo_fcr
;Tobix was here
	stx xtemp
	pha
	ldx #$f2   ;select Silversurfer
	lda #fifo_fcr
	sca			; set A[4..0] and Csel[3..0]
	lda #%10000111
	ist

	; set dlab
;	ldx #%10000011 ; we assmume 8n1
;	stx fifo_lcr
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_lcr
	sca			; set A[4..0] and Csel[3..0]
	lda #%10000011
	ist

	pla
	; set baudrate
	asl a
	tax
	lda debug_baudrates,x
;Tobix was here
	pha
;	sta fifo_dll
	lda debug_baudrates+1,x
;	sta fifo_dlm
	pha
	ldx #$f2   ;select Silversurfer
	lda #fifo_dlm
	sca			; set A[4..0] and Csel[3..0]
	pla
	ist
	ldx #$f2   ;select Silversurfer
	lda #fifo_dll
	sca			; set A[4..0] and Csel[3..0]
	pla
	ist

	; reset dlab
;	lda #%00000011
;	sta fifo_lcr
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_lcr
	sca			; set A[4..0] and Csel[3..0]
	lda #%00000011
	ist

	ldx #$ff		;deselcet all CEs
	sca			;very importend for the other stuff
	ldx xtemp
	rts


_debug_get:
	bit sspresent
	bpl @return

;	lda fifo_lsr  ; check if byte available
;Tobix was here
	stx xtemp
	ldx #$f2   ;select Silversurfer
	lda #fifo_lsr
	sca			; set A[4..0] and Csel[3..0]
	ild			; read MB[7..0]
	and #1
	bne @byteready ; yes

	; activate rts
;	lda #%00000011
;	sta fifo_mcr
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_mcr
	sca			; set A[4..0] and Csel[3..0]
	lda #%00000011
	ist

@waitbyte:
;	lda fifo_lsr  ; check if byte available
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_lsr
	sca			; set A[4..0] and Csel[3..0]
	ild			; read MB[7..0]
	and #1
	beq @waitbyte

@byteready:
	; deactivate rts
;	lda #%00000001
;	sta fifo_mcr
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_mcr
	sca			; set A[4..0] and Csel[3..0]
	lda #%00000001
	ist

	; get byte
;	lda fifo_rxd
;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_rxd
	sca			; set A[4..0] and Csel[3..0]
	ild			; read MB[7..0]

	ldx #$ff		;deselcet all CEs
	sca			;very importend for the other stuff
	ldx xtemp
@return:
	clc
	rts


_debug_put:
	bit sspresent
	bpl @return

	stx xtemp
	pha
	; transmit buf ready?
;@waitbuf:
;	lda fifo_lsr
;	and #%00100000
;	beq @waitbuf
	; reciever ready?
;@waitrecv:
;	lda fifo_msr
;	and #%00010000
;	beq @waitrecv

;Tobix was here
	ldx #$f2   ;select Silversurfer
	lda #fifo_lsr
	sca			; set A[4..0] and Csel[3..0]
@waitbuf:
	ild			; read MB[7..0]
	and #%00100000
	beq @waitbuf
	ldx #$f2   ;select Silversurfer
	lda #fifo_msr
	sca			; set A[4..0] and Csel[3..0]
@waitrecv:
	ild			; read MB[7..0]
	and #%00010000
	beq @waitrecv

	ldx #$f2   ;select Silversurfer
	lda #fifo_txd
	sca			; set A[4..0] and Csel[3..0]
	pla

;	sta fifo_txd
	ist			;write to silversurfer

	ldx #$ff		;deselcet all CEs
	sca			;very importend for the other stuff
	ldx xtemp
	
@return:
	clc
	rts


_debug_crlf:
	pha
	lda #13
	jsr debug_put
	lda #10
	jsr debug_put
	pla
	rts


_debug_puthex:
	pha
	stx xtemp
	lsr
	lsr
	lsr
	lsr
	tax
	lda hextoascii,x
	jsr debug_put
	pla
	and #$0f
	tax
	lda hextoascii,x
	ldx xtemp
	jmp debug_put

	.bss

xtemp:	.res 1


	.code

_debug_putdigit:
	pha
	clc
	adc #'0'
	jsr debug_put
	pla
	rts


	.rodata

hextoascii:
	.byte "0123456789abcdef"
