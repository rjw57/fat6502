	.include "drivecpu.i"

	.export boot
	.export bootconfig

	.import cluster
	.import clusterbuf
	.import vol_cdboot
	.import vol_cdroot
	.import vol_dir_first
	.import vol_dir_next
	.import vol_next_clust
	.import vol_read_clust
	.import vol_stat
	.import vol_isrom
	.import vol_isfpgabin
	.import vol_firstnamechar
	.import vol_endofdir

	.import romaddr
	.import stat_length
	.import stat_cluster
	.import vol_secperclus

	.import debug_puts
	.import debug_crlf
	.import debug_puthex


	.zeropage

loadptr:	.res 2	; load pointer


	.bss

	.align 64
imagecluster:		.res 64	; 16 * 32-bit image cluster addresses
imageaddress:		.res 64	; 16 * 32-bit load addresses
imagelength:		.res 64	; 16 * 32-bit image lengths
fpgacluster:		.res 4	; 32-bit fpga cluster address
fpgalength:		.res 4	; 32-bit fpga length
loadaddress:		.res 4	; 32-bit load address
loadlength:		.res 4	; 32-bit file length
loadend:		.res 4	; 32-bit load address + file length
storevector:		.res 2	; jump vector for indirect store
fpgafound:		.res 1	; flag if fpga file found
imagenum:		.res 1	; pointer to the image table
bootconfig:		.res 1	; selected configuration


	.code

; try to boot from the current partition
;
; * the boot images should be in a dir in the root called BOOT
; * there can be a total of 10 configs, numbered 0-9
; * each config should as a bare minium have a file named xFPGA.BIN
;   where x is the config number
; * each config may also have up to 16 memory images named xRaaaaaa.BIN
;   where x is the config number and aaaaaa is the 24-bit address in hex
;   where the image should be loaded
; * each config may also have a file called 0DESC.TXT which is a plain ascii
;   file with CR/LF linebreaks that should contain a one line description of
;   the configuration, with max 32 characters. the other lines are optional
;   and should have max 39 characters per line 
;
; example:
;
; BOOT/0FPGA.BIN
; BOOT/0R01A000.BIN
; BOOT/0R01E000.BIN
; BOOT/0DESC.TXT
boot:
	ldx #63			; clear image tables
	lda #0
@clearimage:
	sta imagecluster,x
	sta imageaddress,x
	sta imagelength,x
	dex
	bpl @clearimage

	ldx #3			; clear fpga table
@clearfpga:
	sta fpgacluster,x
	sta fpgalength,x
	dex
	bpl @clearfpga

	sta imagenum
	sta fpgafound

	ldax msg_cdroot
	jsr debug_puts
	jsr vol_cdroot		; start in the root dir

	ldax msg_cdboot
	jsr debug_puts
	jsr vol_cdboot		; change directory
	bcs @error		; no boot directory? fux0red

	jsr vol_dir_first	; find the first dir entry

@checkentry:
	jsr vol_endofdir	; check for end of dir
	beq @foundlast

	jsr vol_firstnamechar	; check if it starts with the right number
	sec
	sbc #$30
	cmp bootconfig
	bne @next

	jsr vol_isfpgabin	; check if it's xFPGA.BIN
	bcs @notfpgabin
	jsr @foundfpgabin
	jmp @next
@notfpgabin:

	jsr vol_isrom		; check if it's an image file
	bcs @next
	jsr @foundimage
	;jmp @next

@next:
	jsr vol_dir_next	; find the next dir entry
	bcc @noerror		; premature end of dir

@error:
	sec
	rts
@noerror:

	jmp @checkentry

	; ok, we have found all the config files

@foundlast:
	lda fpgafound		; did we find an fpga config?
	beq @error
	jsr loadfpga		; upload it
	bcs @error

	ldx imagenum		; check list of found images
	beq @done

	ldax msg_loadingroms
	jsr debug_puts

	ldx imagenum
@copynext:
	dex			; copy the relevant entry
	ldy #3

@copyentry:
	lda imagecluster,x
	sta cluster,y

	lda imageaddress,x
	sta loadaddress,y

	lda imagelength,x
	sta loadlength,y

	dex
	dey
	bpl @copyentry

	inx
	stx imagenum

	jsr loadimage		; load the image into memory
	bcs @error

	ldx imagenum
	bne @copynext

@done:
	clc
	rts

@foundfpgabin:
	ldax msg_foundfpgabin
	jsr debug_puts
	jsr vol_stat
	ldx #3
:	lda stat_cluster,x
	sta fpgacluster,x
	lda stat_length,x
	sta fpgalength,x
	dex
	bpl :-
	inc fpgafound		; mark it as found
	rts


@foundimage:
	ldax msg_foundrom
	jsr debug_puts
	ldx imagenum		; convert hex filename to load address
	ldy #5			; there is no error checking here!
@convertaddr:
	lda romaddr,y
	jsr asciitohex
	sta imageaddress,x
	dey
	lda romaddr,y
	jsr asciitohex
	asl
	asl
	asl
	asl
	ora imageaddress,x
	sta imageaddress,x
	inx
	dey
	bpl @convertaddr
	lda #0			; msb is 0
	sta imageaddress,x

	lda imageaddress-1,x
	jsr debug_puthex
	lda imageaddress-2,x
	jsr debug_puthex
	lda imageaddress-3,x
	jsr debug_puthex
	jsr debug_crlf

	jsr vol_stat

	ldx imagenum
	ldy #0			; copy the length and start cluster
@copylength:
	lda stat_length,y
	sta imagelength,x
	lda stat_cluster,y
	sta imagecluster,x
	inx
	iny
	cpy #4
	bne @copylength

	stx imagenum
	rts


; convert ascii to hex digit
asciitohex:
	sec
	sbc #$30
	cmp #10
	bcc @skip
	;sec
	sbc #7
@skip:
	rts


; load fpga config
loadfpga:
	ldax msg_loadingfpga
	jsr debug_puts
	ldx #3			; copy pointers
@copy:
	lda fpgacluster,x
	sta cluster,x
	lda fpgalength,x
	sta loadend,x
	lda #0
	sta loadaddress,x
	dex
	bpl @copy

	lda #<storefpga		; store to fpga config
	sta storevector
	lda #>storefpga
	sta storevector+1

	jmp load


; load a memory image to system ram
loadimage:
	ldx #0			; address + length = end
	clc
	php
@add:
	plp
	lda loadaddress,x
	adc loadlength,x
	sta loadend,x
	php
	inx
	cpx #4
	bne @add
	plp

	lda #<storeimage	; store to ram
	sta storevector
	lda #>storeimage
	sta storevector+1

	ldax msg_loadingrom
	jsr debug_puts

	lda loadaddress+3
	jsr debug_puthex
	lda loadaddress+2
	jsr debug_puthex
	lda loadaddress+1
	jsr debug_puthex
	lda loadaddress
	jsr debug_puthex

	ldax msg_romtoaddr
	jsr debug_puts

	lda loadend+3
	jsr debug_puthex
	lda loadend+2
	jsr debug_puthex
	lda loadend+1
	jsr debug_puthex
	lda loadend
	jsr debug_puthex

	;dputs msg_romcluster
	;lda cluster+3
	;dputnum
	;lda cluster+2
	;dputnum
	;lda cluster+1
	;dputnum
	;lda cluster
	;dputnum

	jsr debug_crlf

	;jmp load


; load routine for loadimage/loadfpga
load:
@nextcluster:
	;dputs msg_readcluster
	;lda cluster+3
	;dputnum
	;lda cluster+2
	;dputnum
	;lda cluster+1
	;dputnum
	;lda cluster
	;dputnum
	;dputs msg_crlf

	jsr vol_read_clust	; read the first cluster
	bcc @ok

	jmp @error

@ok:	;dputs msg_loadaddress
	;lda loadaddress+3
	;dputnum
	;lda loadaddress+2
	;dputnum
	;lda loadaddress+1
	;dputnum
	;lda loadaddress
	;dputnum
	;dputs msg_crlf

	lda #<clusterbuf	; point to the buffer
	sta loadptr
	lda #>clusterbuf
	sta loadptr+1

	ldy #0
@upload:
	jsr @store		; indirect store

	inc loadaddress		; increment our byte counter
	bne @skip3
	inc loadaddress+1
	bne @skip3
	inc loadaddress+2
	;bne @skip3		; uncomment for 32-bit loads
	;inc loadaddress+3
@skip3:

	lda loadaddress		; see if we're done uploading
	cmp loadend
	bne @next
	lda loadaddress+1
	cmp loadend+1
	bne @next
	lda loadaddress+2
	cmp loadend+2
	bne @next
	;lda loadaddress+3	; uncomment for 32-bit loads
	;cmp loadend+3
	;bne @next

	;dputs msg_loaddone

	clc
	rts

@store:
	jmp (storevector)	; indirect store springboard

@next:
	iny
	bne @upload
	inc loadptr+1

	lda vol_secperclus	; check for end of cluster
	asl
	;clc
	adc #>clusterbuf
	cmp loadptr+1
	bne @upload

	jsr vol_next_clust	; find next cluster in chain
	bcs @error
	beq @error		; premature end of file
	jmp @nextcluster

@error:
	ldax msg_loadfailed
	jsr debug_puts

	sec
	rts


storefpga:
	lda (loadptr),y		; grab a byte
	saf			; feed the fpga
				; simple enough, eh?
	;dputs msg_writingbyte
	;dputnum32 loadaddress
	;dputs msg_crlf
	rts

storeimage:
	lda loadaddress		; set the 24-bit load address
	sal			; in the system ram registers
	lda loadaddress+1
	sau
	lda loadaddress+2
	sab
	lda (loadptr),y		; grab a byte
	mst			; store it in system ram
	;dputs msg_writingbyte
	;dputnum32 loadaddress
	rts


	.rodata

msg_loadfailed:
	.byte "Load failed",13,10,0
msg_romtoaddr:
	.byte " to ",0
msg_loadingroms:
	.byte "Loading ROM images",13,10,0
msg_loadingrom:
	.byte "Uploading ROM image from ",0
msg_loadingfpga:
	.byte "Uploading FPGA config",13,10,0
msg_foundfpgabin:
	.byte "Found FPGA config file",13,10,0
msg_foundrom:
	.byte "Found ROM image: ",0
msg_cdroot:
	.byte "cd /",13,10,0
msg_cdboot:
	.byte "cd boot/",13,10,0
