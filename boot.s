	.include "drivecpu.i"

	.export boot
	.export drawbooticon
	.export printvolname
	.export bootconfig
	.export entermenu

	.import bootmenu

	.import cluster
	.import clusterbuf
	.import flashbuf
	.import vol_cdboot
	.import vol_cdroot
	.import vol_dir_first
	.import vol_dir_next
	.import vol_next_clust
	.import vol_read_clust
	.import vol_stat
	.import vol_isrom
	.import vol_isfpgabin
	.import vol_isdrivebin
	.import vol_isflashbin
	.import vol_firstnamechar
	.import vol_endofdir
	.import vol_volname

	.import romaddr
	.import stat_length
	.import stat_cluster
	.import vol_secperclus

	.importzp clusterptr, ptr

	.import debug_puts
	.import debug_crlf
	.import debug_puthex

	.import gfx_gotoxy
	.import gfx_puts
	.import gfx_drawicon
	.import devicon
	.import devtype

	.zeropage

loadptr:	.res 2	; load pointer


	.bss

	.align 64
imagecluster:		.res 64	; 16 * 32-bit image cluster addresses
imageaddress:		.res 64	; 16 * 32-bit load addresses
imagelength:		.res 64	; 16 * 32-bit image lengths
drivebincluster:	.res 4	; 32-bit drive bin cluster address
drivebinlength:		.res 4	; 32-bit drive bin length
fpgacluster:		.res 4	; 32-bit fpga cluster address
fpgalength:		.res 4	; 32-bit fpga length
loadaddress:		.res 4	; 32-bit load address
loadlength:		.res 4	; 32-bit file length
loadend:		.res 4	; 32-bit load address + file length
loadleft:		.res 4	; load counter
storevector:		.res 2	; jump vector for indirect store
fpgafound:		.res 1	; flag if fpga file found
drivebinfound:		.res 1	; flag if drive bin found
imagenum:		.res 1	; pointer to the image table
bootconfig:		.res 1	; selected configuration (ASCII)
entermenu:		.res 1	; non-0 if we should display boot menu


	.code

; try to boot from the current partition
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
	sta drivebincluster,x
	sta drivebinlength,x
	dex
	bpl @clearfpga

	sta imagenum
	sta fpgafound
	sta drivebinfound

	ldax msg_cdroot
	jsr debug_puts
	jsr vol_cdroot		; start in the root dir

	ldax msg_cdboot
	jsr debug_puts
	jsr vol_cdboot		; change directory
	bcs @error		; no boot directory? fux0red

	jsr vol_dir_first	; find the first dir entry

	lda bootconfig
	cmp #'F'
	bne @checkmenu
	jmp bootflash		; load flash image instead

@checkmenu:
	lda entermenu
	beq @drawicon

	jsr bootmenu		; display boot menu
	;bcs @error		; just try to boot instead
	jsr vol_cdroot		; all over again
	jsr vol_cdboot
	jsr vol_dir_first

@drawicon:
	ldx #28			; print booting
	ldy #12
	jsr gfx_gotoxy
	ldax msg_bootingfrom
	jsr gfx_puts
	jsr drawbooticon	; draw device icon
	jsr printvolname	; print volume name

@checkentry:
	jsr vol_endofdir	; check for end of dir
	beq @foundlast

	jsr vol_firstnamechar	; check if it starts with the right number
	cmp bootconfig
	bne @next

	jsr vol_isdrivebin	; check if it's xDRIVE.BIN
	bcs @notdrivebin
	jsr @founddrivebin
	jmp @next
@notdrivebin:
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
	bcc @checkentry		; premature end of dir

@error:
	sec
	rts

	; ok, we have found all the config files

@foundlast:
	lda fpgafound		; did we find an fpga config?
	beq @error
	jsr loadfpga		; upload it
	bcs @error

	ldx imagenum		; check list of found images
	beq @doneimg

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

@doneimg:
	lda drivebinfound
	beq @done

	jsr loaddrivebin	; too late to fail anyway
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

@founddrivebin:
	ldax msg_founddrivebin
	jsr debug_puts
	jsr vol_stat
	ldx #3
:	lda stat_cluster,x
	sta drivebincluster,x
	lda stat_length,x
	sta drivebinlength,x
	dex
	bpl :-
	inc drivebinfound	; mark it as found
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


; draw boot device icon and print volume name
drawbooticon:
	ldx #38			; redraw icon
	ldy #14
	jsr gfx_gotoxy
	lda devtype
	asl
	tay
	lda devicon+1,y
	tax
	lda devicon,y
	jmp gfx_drawicon

printvolname:
	jsr vol_volname		; print volume name
	tya
	lsr
	eor #$ff
	clc
	adc #41
	tax
	ldy #17
	jsr gfx_gotoxy
	jsr vol_volname
	jmp gfx_puts



; load FLASH.BIN
bootflash:
@checkentry:
	jsr vol_endofdir	; check for end of dir
	bne @check
	sec
	rts
@check:
	jsr vol_isflashbin	; check if it's FLASH.BIN
	bcs @next
	jmp @loadflashbin
@next:
	jsr vol_dir_next	; find the next dir entry
	bcc @checkentry		; premature end of dir

@error:
	sec
	rts

@loadflashbin:
	ldax msg_foundflashbin
	jsr debug_puts
	jsr vol_stat
	ldx #3
:	lda stat_cluster,x
	sta cluster,x
	dex
	bpl :-
	lsr stat_length+2	; divide by 2
	ror stat_length+1	; gives us the number of 512 byte sectors in s_l+1

	lda vol_secperclus	; divide by number of sectors per cluster
:	lsr
	bcs :+
	lsr stat_length+1
	jmp :-
:	lda stat_length+1
	sta loadend
	ldax clusterbuf
	stax clusterptr
	jsr loadclusters
	bcc @ok
	rts
@ok:
	ldax clusterbuf		; copy code to $2000
	stax clusterptr
	ldax flashbuf
	stax ptr
	ldx #$1f
	ldy #0
@copy:
	lda (clusterptr),y
	sta (ptr),y
	iny
	bne @copy
	inc clusterptr+1
	inc ptr+1
	dex
	bne @copy

	jsr flashbuf		; lock and load


; load drive code to clusterbuf and execute
loaddrivebin:
	ldax msg_loadingdrivebin
	jsr debug_puts
	ldx #3
:	lda drivebincluster,x
	sta cluster,x
	dex
	bpl :-

	lsr drivebinlength+2	; divide by 2
	ror drivebinlength+1	; gives us the number of 512 byte sectors in dbl+1

	lda vol_secperclus	; divide by number of sectors per cluster
:	lsr
	bcs :+
	lsr drivebinlength+1
	jmp :-
:	lda drivebinlength+1
	sta loadend

	ldax clusterbuf
	stax clusterptr
	jsr loadclusters
	jsr clusterbuf		; execute


; load clusters
loadclusters:
@load:
	jsr vol_read_clust
	bcs @done
	dec loadend
	beq @done
	jsr vol_next_clust
	bcc @load
@done:
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
	sta loadleft,x
	dex
	bpl @copy

	lda #%00000110		; halt 65816
	ctl

@nextcluster:
	ldax clusterbuf
	stax clusterptr
	jsr vol_read_clust	; read the first cluster
	bcs @error

	lda #<clusterbuf	; point to the buffer
	sta loadptr
	lda #>clusterbuf
	sta loadptr+1

@upload:
	lda loadleft + 1	; any 256-byte pages left?
	ora loadleft + 2
	beq @loadlast		; nope, load the last few bytes

	ldy #0
:	lda (loadptr),y		; grab a byte
	saf			; feed the fpga
	iny
	bne :-

	dec loadleft + 1	; decrement number of pages left
	lda loadleft + 1
	cmp #$ff
	bne :+
	dec loadleft + 2
:	inc loadptr+1		; increment load ptr

	lda vol_secperclus	; check for end of cluster
	asl
	;clc
	adc #>clusterbuf
	cmp loadptr+1
	bne @upload

	jsr vol_next_clust	; find next cluster in chain
	bcs @error
	bne @nextcluster

@error:
	ldax msg_loadfailed
	jsr debug_puts

	sec
	rts

@loadlast:
	lda loadleft		; bytes left to load
	beq @done

:	lda (loadptr),y
	saf
	iny
	cpy loadleft
	bne :-
@done:
	clc			; all done
	rts



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

; load routine for loadimage
@nextcluster:
	ldax clusterbuf
	stax clusterptr
	jsr vol_read_clust	; read the first cluster
	bcs @error

	lda #<clusterbuf	; point to the buffer
	sta loadptr
	lda #>clusterbuf
	sta loadptr+1

	ldy #0
@upload:
	lda loadaddress		; set the 24-bit load address
	sal			; in the system ram registers
	lda loadaddress+1
	sau
	lda loadaddress+2
	sab
	lda (loadptr),y		; grab a byte
	mst			; store it in system ram

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

	clc
	rts

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
	beq @eoferror		; premature end of file
	jmp @nextcluster

@error:
	ldax msg_loadfailed
	jsr debug_puts

	sec
	rts

@eoferror:
	ldax msg_faileof
	jsr debug_puts

	ldax msg_loadaddr
	jsr debug_puts
	lda loadaddress+3
	jsr debug_puthex
	lda loadaddress+2
	jsr debug_puthex
	lda loadaddress+1
	jsr debug_puthex
	lda loadaddress
	jsr debug_puthex
	jsr debug_crlf

	ldax msg_loadend
	jsr debug_puts
	lda loadend+3
	jsr debug_puthex
	lda loadend+2
	jsr debug_puthex
	lda loadend+1
	jsr debug_puthex
	lda loadend
	jsr debug_puthex
	jsr debug_crlf

	ldax msg_endcluster
	jsr debug_puts
	lda cluster+3
	jsr debug_puthex
	lda cluster+2
	jsr debug_puthex
	lda cluster+1
	jsr debug_puthex
	lda cluster
	jsr debug_puthex
	jsr debug_crlf

	sec
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
msg_loadingdrivebin:
	.byte "Loading drive code",13,10,0
msg_foundfpgabin:
	.byte "Found FPGA config file",13,10,0
msg_foundrom:
	.byte "Found ROM image: ",0
msg_founddrivebin:
	.byte "Found drive code binary",13,10,0
msg_foundflashbin:
	.byte "Found FLASH.BIN",13,10,0
msg_cdroot:
	.byte "cd /",13,10,0
msg_cdboot:
	.byte "cd boot/",13,10,0
msg_faileof:
	.byte "Premature end of file",13,10,0
msg_loadaddr:
	.byte "Load address: ",0
msg_loadend:
	.byte "Load end:     ",0
msg_endcluster:
	.byte "End cluster:  ",0

msg_bootingfrom:
	.byte "        Booting...       ",0
