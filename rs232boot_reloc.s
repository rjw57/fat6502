	.include "drivecpu.i"

	.export rs232boot

	.importzp dest

	.import resetvector

	.import __ROM_SIZE__
	.import __ROM_START__


	.zeropage

rs232_ptr:	.res 2


	.segment "RELOC"

;cksum:		.res 1


rs232boot:
	ldax waitingmsg1
	jsr rs232_puts
	lda #>__ROM_SIZE__
	jsr rs232_puthex
	lda #0
	jsr rs232_puthex
	ldax waitingmsg2
	jsr rs232_puts

	ldax __ROM_START__
	stax dest
	ldx #>__ROM_SIZE__
	ldy #0
;	sty cksum

@getbyte:
	jsr rs232_get
	sta (dest),y
	;clc
	;adc cksum
	;sta cksum
	iny
	bne @getbyte

	lda #'.'
	jsr rs232_put

	inc dest+1
	dex
	bne @getbyte

	;ldax checkmsg
	;jsr rs232_puts
	;lda cksum
	;jsr rs232_puthex
	ldax execmsg
	jsr rs232_puts

	jsr rs232_done
	jmp (resetvector)


waitingmsg1:
	.byte "Waiting for $",0
waitingmsg2:
	.byte " bytes of ROM code",13,10,0
;checkmsg:
;	.byte 13,10
;	.byte "ADC checksum = $",0
execmsg:
	.byte 13,10
	.byte "Executing...",13,10
	.byte 13,10,0


;-----------------------------------------------------------------------
; RS-232 routines
; based on groepaz' source
;-----------------------------------------------------------------------


A16550BASE	= $3f20
fifo_rxd	= A16550BASE + 0	; (r)
fifo_txd	= A16550BASE + 0	; (w)
fifo_dll	= A16550BASE + 0
fifo_dlm	= A16550BASE + 1
fifo_ier	= A16550BASE + 1
fifo_fcr	= A16550BASE + 2	; (w)
fifo_iir	= A16550BASE + 2	; (r)
fifo_lcr	= A16550BASE + 3
fifo_mcr	= A16550BASE + 4
fifo_lsr	= A16550BASE + 5
fifo_msr	= A16550BASE + 6	; (r)
fifo_scratch	= A16550BASE + 7	; (r/w)

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


rs232_puts:
	sta rs232_ptr
	stx rs232_ptr+1
	ldy #0
@print:
	lda (rs232_ptr),y
	beq @done
	jsr rs232_put
	iny
	bne @print
@done:	rts


rs232_done:
	; disable nmi's from ssurfer
	lda #0
	sta fifo_ier

	; deactivate dtr
	sta fifo_mcr

	clc
	rts


rs232_get:
	lda fifo_lsr  ; check if byte available
	and #1
	bne @byteready ; yes

	; activate rts
	lda #%00000011
	sta fifo_mcr
@waitbyte:
	lda fifo_lsr  ; check if byte available
	and #1
	beq @waitbyte

@byteready:
	; deactivate rts
	lda #%00000001
	sta fifo_mcr

	; get byte
	lda fifo_rxd
@return:
	clc
	rts


rs232_put:
	pha
	; transmit buf ready?
@waitbuf:
	lda fifo_lsr
	and #%00100000
	beq @waitbuf
	; reciever ready?
@waitrecv:
	lda fifo_msr
	and #%00010000
	beq @waitrecv

	pla
	sta fifo_txd
@return:
	clc
	rts


rs232_puthex:
	pha
	stx @xtemp
	lsr
	lsr
	lsr
	lsr
	tax
	lda hextoascii,x
	jsr rs232_put
	pla
	and #$0f
	tax
	lda hextoascii,x
	ldx @xtemp
	jmp rs232_put

@xtemp:
	.res 1

hextoascii:
	.byte "0123456789abcdef"
