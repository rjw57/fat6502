	.include "drivecpu.i"

	.export boot, comparedirname, part_fstype
	.export bootconfig, part_secperclus

	.importzp dirptr, loadptr, nameptr
	.importzp fs_fat16
	.importzp fs_fat32

	.import cluster
	.import clusterbuf
	.import vol_cd
	.import vol_cdroot
	.import vol_dir_first
	.import vol_dir_next
	.import vol_next_clust
	.import vol_read_clust

	.import debug_puts
	.import debug_puthex
	.import dstr_cdroot
	.import dstr_cdboot
	.import dstr_readingdir
	.import dstr_foundfpgabin
	.import dstr_foundrom
	.import dstr_loadingfpga
	.import dstr_loadingrom
	.import dstr_imagenum
	.import dstr_crlf
	.import dstr_romtoaddr
	.import dstr_romcluster
	.import dstr_readcluster
	.import dstr_loadaddress
	.import dstr_loadfailed
	.import dstr_loaddone
	.import dstr_loadingroms
	.import dstr_notend
	.import dstr_end
	.import dstr_writingbyte


	.bss

	.align 256
imagecluster:	.res 64	; 16 * 32-bit image cluster addresses
imageaddress:	.res 64	; 16 * 32-bit load addresses
imagelength:	.res 64	; 16 * 32-bit image lengths
fpgacluster:	.res 4	; 32-bit fpga cluster address
fpgalength:	.res 4	; 32-bit fpga length
loadaddress:	.res 4	; 32-bit load address
loadlength:	.res 4	; 32-bit file length
loadend:	.res 4	; 32-bit load address + file length
storevector:	.res 2	; jump vector for indirect store
fpgafound:	.res 1	; flag if fpga file found
imagenum:	.res 1	; pointer to the image table
part_fstype:	.res 1	; file system type
bootconfig:	.res 1	; selected configuration
part_secperclus:	.res 4	; number of 512-byte sectors per cluster


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

	dputs dstr_cdroot
	jsr vol_cdroot		; start in the root dir

	lda #<bootdirname	; the name to look for
	sta nameptr
	lda #>bootdirname
	sta nameptr+1

	dputs dstr_cdboot
	jsr vol_cd		; change directory
	bcs @error		; no boot directory? fux0red

	lda #<fpganame		; the name to look for
	sta nameptr
	lda #>fpganame
	sta nameptr+1

	;dputs dstr_readingdir
	jsr vol_dir_first	; find the first dir entry

@checkentry:
	ldy #0			; check for end of dir
	lda (dirptr),y
	beq @foundlast

	lda bootconfig		; check if it starts with the right number
	ora #$30
	ldy #0
	cmp (dirptr),y
	bne @next

	jsr checkdotbin		; check if it ends with .BIN
	bne @next

	ldy #10			; check if it's xFPGA.BIN
	jsr comparedirname
	cpy #0			; we know this fails, but check where
	bne @notfpgabin
	jsr @foundfpgabin
	jmp @next
@notfpgabin:

	ldy #1			; check if it's an image file
	lda (dirptr),y
	cmp #'R'
	bne @next
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

	dputs dstr_loadingroms

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
	dputs dstr_foundfpgabin
	lda part_fstype
	cmp #fs_fat32
	bne @fat16

	ldy #$14		; copy the start cluster
	lda (dirptr),y
	sta fpgacluster+2
	iny
	lda (dirptr),y
	sta fpgacluster+3
	jmp @skip1

@fat16:
	cmp #fs_fat16
	bne @error

	lda #0
	sta fpgacluster+2
	sta fpgacluster+3

@skip1:
	ldy #$1a
	lda (dirptr),y
	sta fpgacluster
	iny
	lda (dirptr),y
	sta fpgacluster+1

	iny			; copy the file length
	lda (dirptr),y		; we should make sure that the length
	sta fpgalength		; is $00028c35...
	iny
	lda (dirptr),y
	sta fpgalength+1
	iny
	lda (dirptr),y
	sta fpgalength+2
	iny
	lda (dirptr),y
	sta fpgalength+3

	;lda #16			; fake filesize of 16
	;sta fpgalength
	;lda #0
	;sta fpgalength+1
	;sta fpgalength+2
	;sta fpgalength+3

	inc fpgafound		; mark it as found
	rts

@foundimage:
	dputs dstr_foundrom
	ldx imagenum		; convert hex filename to load address
	ldy #7			; there is no error checking here!
@convertaddr:
	lda (dirptr),y
	jsr asciitohex
	sta imageaddress,x
	dey
	lda (dirptr),y
	jsr asciitohex
	asl
	asl
	asl
	asl
	ora imageaddress,x
	sta imageaddress,x
	inx
	dey
	cpy #1			; 6 digits
	bne @convertaddr
	lda #0			; msb is 0
	sta imageaddress,x

	lda imageaddress-1,x
	dputnum
	lda imageaddress-2,x
	dputnum
	lda imageaddress-3,x
	dputnum
	dputs dstr_crlf

	ldy #$1f
@copylength:
	lda (dirptr),y
	sta imagelength,x
	dex
	dey
	cpy #$1b
	bne @copylength

	inx			; copy the start cluster

	;lda #16			; fake filesize of 16
	;sta imagelength,x
	;lda #0
	;sta imagelength+1,x
	;sta imagelength+2,x
	;sta imagelength+3,x

	ldy #$1a

	lda (dirptr),y
	sta imagecluster,x
	inx
	iny
	lda (dirptr),y
	sta imagecluster,x
	inx

	lda part_fstype
	cmp #fs_fat32
	beq @fat32i

	lda #0
	sta imagecluster,x
	inx
	lda #0
	sta imagecluster,x
	jmp @donecopying

@fat32i:
	ldy #$14
	lda (dirptr),y
	sta imagecluster,x
	inx
	iny
	lda (dirptr),y
	sta imagecluster,x

@donecopying:
	inx
	stx imagenum

	;dputs dstr_imagenum
	;lda imagenum
	;dputnum
	;dputs dstr_crlf

	rts

bootdirname:
	.byte "BOOT    ","   "
fpganame:
	.byte "xFPGA   ","BIN"


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


; check if the dir entry pointed to by dirptr ends with .BIN
checkdotbin:
	ldy #8
	lda (dirptr),y
	cmp #'B'
	bne @done

	iny
	lda (dirptr),y
	cmp #'I'
	bne @done

	iny
	lda (dirptr),y
	cmp #'N'

@done:
	rts


; load fpga config
loadfpga:
	dputs dstr_loadingfpga
	ldx #3		; copy pointers
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
	ldx #0		; address + length = end
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

	dputs dstr_loadingrom

	lda loadaddress+3
	dputnum
	lda loadaddress+2
	dputnum
	lda loadaddress+1
	dputnum
	lda loadaddress
	dputnum

	dputs dstr_romtoaddr

	lda loadend+3
	dputnum
	lda loadend+2
	dputnum
	lda loadend+1
	dputnum
	lda loadend
	dputnum

	;dputs dstr_romcluster
	;lda cluster+3
	;dputnum
	;lda cluster+2
	;dputnum
	;lda cluster+1
	;dputnum
	;lda cluster
	;dputnum

	dputs dstr_crlf

	;jmp load


; load routine for loadimage/loadfpga
load:
@nextcluster:
	;dputs dstr_readcluster
	;lda cluster+3
	;dputnum
	;lda cluster+2
	;dputnum
	;lda cluster+1
	;dputnum
	;lda cluster
	;dputnum
	;dputs dstr_crlf

	jsr vol_read_clust	; read the first cluster
	bcc @ok

	jmp @error

@ok:	;dputs dstr_loadaddress
	;lda loadaddress+3
	;dputnum
	;lda loadaddress+2
	;dputnum
	;lda loadaddress+1
	;dputnum
	;lda loadaddress
	;dputnum
	;dputs dstr_crlf

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

	;dputs dstr_loaddone

	clc
	rts

@store:
	jmp (storevector)	; indirect store springboard

@next:
	iny
	bne @upload
	inc loadptr+1

	lda part_secperclus	; check for end of cluster
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
	dputs dstr_loadfailed

	sec
	rts


storefpga:
	lda (loadptr),y		; grab a byte
	saf		; feed the fpga
			; simple enough, eh?
	;dputs dstr_writingbyte
	;dputnum32 loadaddress
	;dputs dstr_crlf
	rts

storeimage:
	lda loadaddress		; set the 24-bit load address
	sal		; in the system ram registers
	lda loadaddress+1
	sau
	lda loadaddress+2
	sab
	lda (loadptr),y		; grab a byte
	mst		; store it in system ram
	;dputs dstr_writingbyte
	;dputnum32 loadaddress
	rts


; compare two strings at dirptr and nameptr
comparedirname:
@compare:
	lda (dirptr),y
	cmp (nameptr),y
	bne @exit
	dey
	bpl @compare
	lda #0
@exit:
	rts
