;----------------------------------------------------------------------------------
; silver surfer code based on groepaz cc65 code
;----------------------------------------------------------------------------------


	.export debug_init
	.export debug_done
	.export debug_puts
	.export debug_put
	.export debug_puthex
	.export debug_crlf

	.export dstr_crlf
	.export dstr_cdroot
	.export dstr_cdboot
	.export dstr_readingdir
	.export dstr_foundfpgabin
	.export dstr_foundrom
	.export dstr_loadingfpga
	.export dstr_loadingrom
	.export dstr_imagenum
	.export dstr_romtoaddr
	.export dstr_romcluster
	.export dstr_readcluster
	.export dstr_loadaddress
	.export dstr_dircluster
	.export dstr_foundfat16
	.export dstr_foundfat32
	.export dstr_loadfailed
	.export dstr_loaddone
	.export dstr_loadingroms
	.export dstr_notend
	.export dstr_end
	.export dstr_writingbyte


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

debug_init:
	;lda #$55
	;sta fifo_scratch

	; set baudrate
	lda #baud_9600
	jsr debug_setbaud

	;lda fifo_scratch
	;cmp #$55
	;bne @noss

	lda #$80		; we found a silver surfer
	sta sspresent

	; disable nmi's from ssurfer
	lda #0
	sta fifo_ier

	; activate dtr
	lda #1
	sta fifo_mcr

	lda #<@initstr
	ldx #>@initstr
	jsr debug_puts

	clc
	rts

;@noss:
	;lda #0			; no silver surfer found
	;sta sspresent
	;clc
	;rts

@initstr:
	.byte 13,10,"C-ONE debug init",13,10,0


debug_puts:
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


debug_done:
	; disable nmi's from ssurfer
	lda #0
	sta fifo_ier

	; deactivate dtr
	sta fifo_mcr

	clc
	rts


debug_setbaud:
	; reset fifo
	ldx #%10000111
	stx fifo_fcr

	; set dlab
	ldx #%10000011 ; we assmume 8n1
	stx fifo_lcr

	; set baudrate
	asl a
	tax
	lda debug_baudrates,x
	sta fifo_dll
	lda debug_baudrates+1,x
	sta fifo_dlm

	; reset dlab
	lda #%00000011
	sta fifo_lcr
	rts


debug_get:
	bit sspresent
	bpl @return

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


debug_put:
	bit sspresent
	bpl @return

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


debug_crlf:
	lda #13
	jsr debug_put
	lda #10
	jmp debug_put


debug_puthex:
	pha
	stx @xtemp
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
	ldx @xtemp
	jmp debug_put

	.bss

@xtemp:	.res 1


	.rodata

hextoascii:
	.byte "0123456789abcdef"


dstr_cdroot:
	.byte "cd /"
dstr_crlf:
	.byte 13,10,0
dstr_cdboot:
	.byte "cd boot/",13,10,0
dstr_readingdir:
	.byte "Reading directory",13,10,0
dstr_foundfpgabin:
	.byte "Found FPGA config file",13,10,0
dstr_foundrom:
	.byte "Found ROM image: ",0
dstr_loadingfpga:
	.byte "Uploading FPGA config",13,10,0
dstr_loadingrom:
	.byte "Uploading ROM image from ",0
dstr_imagenum:
	.byte "imagenum is now: ",0
dstr_romtoaddr:
	.byte " to ",0
dstr_romcluster:
	.byte " from cluster ",0
dstr_readcluster:
	.byte "Reading cluster: ",0
dstr_loadaddress:
	.byte "Loaded byte ",0
dstr_dircluster:
	.byte "Loading dir cluster ",0
dstr_foundfat16:
	.byte "Found FAT16 partition number ",0
dstr_foundfat32:
	.byte "Found FAT32 partition number ",0
dstr_loadfailed:
	.byte "Load failed",13,10,0
dstr_loaddone:
	.byte "Load done",13,10,0
dstr_loadingroms:
	.byte "Loading ROM images",13,10,0
dstr_notend:
	.byte "and that was fun",13,10,0
dstr_end:
	.byte "and that's the end",13,10,0
dstr_writingbyte:
	.byte "writing byte ",0
