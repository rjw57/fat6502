	.include "drivecpu.i"

	.exportzp fs_iso9660

	.export iso_read_volid
	.export iso_cdboot
	.export iso_cdroot
	.export iso_dir_first
	.export iso_dir_next
	.export iso_next_clust
	.export iso_read_clust
	.export iso_endofdir
	.export iso_isfpgabin
	.export iso_isrom
	.export iso_isflashbin
	.export iso_isdrivebin
	.export iso_stat
	.export iso_firstnamechar
	.export iso_isdesc
	.export iso_volname
	.export iso_write_clust

	.import lba
	.import cluster
	.importzp sectorptr
	.importzp clusterptr

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
volnamelen:	.res 1		; length of volume name
volname:	.res 33		; volume name


	.code

; return pointer and length to volume name
iso_volname:
	ldy volnamelen
	ldax #volname
	rts



; read volume information
iso_read_volid:
	ldax #msg_reading_pvd
	jsr debug_puts

	ldax #clusterbuf		; load primary volume descriptor
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

	ldax #msg_found_volume
	jsr debug_puts

	ldx #0			; print volume name
@printvolname:
	lda clusterbuf+40,x
	sta volname,x		; save volume name
	jsr debug_put
	inx
	cpx #32
	bne @printvolname
	stx volnamelen		; save length
	jsr debug_crlf

	ldx #31			; trim trailing spaces
:	lda volname,x
	cmp #' '
	bne @done
	dec volnamelen
	dex
	bpl :-
@done:
	ldx volnamelen		; terminating 0
	lda #0
	sta volname,x

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
	; fall through


; write cluster
iso_write_clust:
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
	ldax #bootdirname-33	; offset by -33 to compensate
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
	ldax #clusterbuf
	stax clusterptr
	jsr iso_read_clust
	bcc @ok
	rts
@ok:
	ldax #clusterbuf
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
	ldax #fpgabinname-33
	stax nameptr
	jsr comparedirname
	bne @no
returnconfig:
	ldy #33
	lda (dirptr),y
	and #$0f
	clc
	rts


; check if dir entry is xDESC.TXT
iso_isdesc:
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
	ldax #descname-33
	stax nameptr
	jsr comparedirname
	bne @no
	clc
	rts


; check if dir entry is flash code
iso_isflashbin:
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
	ldax #flashbinname-33
	stax nameptr
	jsr comparedirname
	bne @no
@return:
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
	ldax #romname-33
	stax nameptr
	jsr comparedirname
	bne @no

	ldy #40
	ldx #5
:	lda (dirptr),y
	sta romaddr,x
	dey
	dex
	bpl :-

	jmp returnconfig


iso_isdrivebin:
	ldy #32
	lda (dirptr),y
	cmp #12
	beq @maybe
	cmp #10
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldax #drivebinname-33
	stax nameptr
	jsr comparedirname
	bne @no
@return:
	clc
	rts



; compare dir entry name
; set nameptr to name - 33!
comparedirname:
	ldy #32
	lda (dirptr),y
	tax
comparedirname_start:			; call here with x and y set up
	iny
	lda (nameptr),y
	cmp #'?'			; any char matches
	beq @any
	cmp (dirptr),y
	bne @return
@any:
	dex
	bne comparedirname_start
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

	ldy #32			; return name length in y
	lda (dirptr),y
	tay

	ldax dirptr		; return pointer to name in a/x
	clc
	adc #33
	bcc :+
	inx
:
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
	lda clusterptr
	sta sectorptr
	lda clusterptr+1
	sta sectorptr+1
	ldx #3
:	lda cluster,x
	sta lba,x
	dex
	bpl :-
	jsr dev_read_sector
	bcc :+
	rts
:	lda sectorptr
	sta clusterptr
	lda sectorptr+1
	sta clusterptr+1
	rts


	.rodata

bootdirname:
	.byte "BOOT"
fpgabinname:
	.byte "?FPGA.BIN??"
romname:
	.byte "?R??????.BIN??"
flashbinname:
	.byte "FLASH.BIN??"
drivebinname:
	.byte "?DRIVE.BIN??"
descname:
	.byte "?DESC.TXT??"

cd001:
	.byte 1,"CD001",1

msg_reading_pvd:
	.byte "Reading Primary Volume Descriptor",13,10,0
msg_found_volume:
	.byte "Found ISO9660 volume: ",0
