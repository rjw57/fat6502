	.include "drivecpu.i"

	.exportzp fs_iso9660

	.export iso_read_ptable
	.export iso_cdboot
	.export iso_cdroot
	.export iso_dir_first
	.export iso_dir_next
	.export iso_next_clust
	.export iso_read_clust
	.export iso_endofdir
	.export iso_isfpgabin
	.export iso_isrom
	.export iso_stat
	.export iso_firstnamechar

	.import lba
	.import cluster
	.importzp sectorptr

	.import stat_cluster
	.import stat_length
	.import romaddr
	.import vol_secperclus
	.importzp dirptr
	.importzp nameptr

	.import clusterbuf

	.import dev_read_sector

	.import debug_put
	.import debug_puts
	.import debug_putdigit
	.import debug_puthex
	.import debug_crlf


fs_iso9660	= $96


	.bss

rootdir:	.res 4		; first sector of root directory


	.code

; read volume information
iso_read_ptable:
	ldax msg_reading_pvd
	jsr debug_puts

	ldax clusterbuf		; load primary volume descriptor
	stax sectorptr
	lda #16
	sta lba
	lda #0
	sta lba+1
	sta lba+2
	sta lba+3
	jsr dev_read_sector
	bcc @ok
@fail:
	sec
	rts
@ok:
	lda clusterbuf		; volume descriptor type
	cmp #1			; should be 1
	bne @fail

	ldx #6			; check CD001 identifier
@compare:
	lda clusterbuf,x
	cmp cd001,x
	bne @fail
	dex
	bne @compare

	ldax msg_found_volume
	jsr debug_puts

	ldx #0			; print volume name
@printvolname:
	lda clusterbuf+40,x
	jsr debug_put
	inx
	cpx #32
	bne @printvolname
	jsr debug_crlf

	lda clusterbuf + 128	; check sector size
	bne @fail		; should be 2048
	lda clusterbuf + 129
	cmp #$08
	bne @fail
	lda #4			; 4 x 512 = 2048
	sta vol_secperclus

	ldx #3
:	lda clusterbuf + 158,x
	sta rootdir,x
	dex
	bpl :-

	clc
	rts


; go to root directory
iso_cdroot:
	ldx #3
:	lda rootdir,x
	sta cluster,x
	dex
	bpl :-
	clc
	rts


; change to boot directory
iso_cdboot:
	ldax (bootdirname-33)	; offset by -33 to compensate
	stax nameptr
	jsr iso_dir_first
	bcc @checkname
@error:
	sec
	rts

@checkname:
	jsr iso_endofdir	; end of dir?
	beq @error

	jsr comparedirname	; check name
	beq @found

	jsr iso_dir_next
	bcc @checkname
	rts

@found:
	ldy #5
	ldx #3
:	lda (dirptr),y
	sta cluster,x
	dey
	dex
	bpl :-

	clc
	rts


; read the first sector into the buffer and point dirptr
; to the first entry
iso_dir_first:
	jsr iso_read_clust
	bcc @ok
	rts
@ok:
	ldax clusterbuf
	stax dirptr
	;clc
	rts


; go to the next entry
iso_dir_next:
	ldy #0
	lda (dirptr),y
	clc
	adc dirptr
	sta dirptr
	bcc :+
	inc dirptr+1
:	clc
	rts


; check if dirptr points to the last entry
iso_endofdir:
	ldy #0
	lda (dirptr),y
	rts


; return the first character of the filename
iso_firstnamechar:
	ldy #33
	lda (dirptr),y
	rts


; check if dir entry is xFPGA.BIN
iso_isfpgabin:
	ldy #32
	lda (dirptr),y
	cmp #11
	beq @maybe
	cmp #9
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldax (fpgabinname-33)
	stax nameptr
	jsr comparedirname
	beq returnconfig
	cpy #43				; we could fail at the version number
	bne @no
returnconfig:
	ldy #33
	lda (dirptr),y
	and #$0f
	clc
	rts


; check if dir entry is a rom image
iso_isrom:
	ldy #32
	lda (dirptr),y
	cmp #14
	beq @maybe
	cmp #12
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldy #34
	lda (dirptr),y
	cmp #'R'
	bne @no

	ldy #41
:	lda dotbinname-41,y
	cmp (dirptr),y
	bne @no
	iny
	cpy #43
	bne :-

	ldy #40
	ldx #5
:	lda (dirptr),y
	sta romaddr,x
	dey
	dex
	bpl :-

	jmp returnconfig


; compare dir entry name
; set nameptr to name - 33!
comparedirname:
	ldy #32
	lda (dirptr),y
	tax
@compare:
	iny
	lda (dirptr),y
	cmp (nameptr),y
	bne @return
	dex
	bne @compare
@return:
	rts


; copy start cluster and length from dir entry
iso_stat:
	ldy #2			; copy start cluster
:	lda (dirptr),y
	sta stat_cluster-2,y
	iny
	cpy #6
	bne :-

	ldy #10			; copy length
:	lda (dirptr),y
	sta stat_length-10,y
	iny
	cpy #14
	bne :-

	clc
	rts


; read the next cluster in the chain
iso_next_clust:
	inc cluster		; gotta love 9660
	bne @done
	inc cluster+1
	bne @done
	inc cluster+2
	bne @done
	inc cluster+3
@done:
	clc
	rts


; read the sector in cluster
iso_read_clust:
	ldax clusterbuf
	stax sectorptr
	ldx #3
:	lda cluster,x
	sta lba,x
	dex
	bpl :-
	jmp dev_read_sector


	.rodata

bootdirname:
	.byte "BOOT"
fpgabinname:
	.byte "0FPGA.BIN;x"
dotbinname:
	.byte ".BIN"

cd001:
	.byte 1,"CD001",1

msg_reading_pvd:
	.byte "Reading Primary Volume Descriptor",13,10,0
msg_found_volume:
	.byte "Found ISO9660 volume: ",0
