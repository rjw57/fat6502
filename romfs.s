	.include "drivecpu.i"

	.exportzp fs_romfs

	.export romfs_read_volid
	.export romfs_cdboot
	.export romfs_cdroot
	.export romfs_dir_first
	.export romfs_dir_next
	.export romfs_next_clust
	.export romfs_read_clust
	.export romfs_endofdir
	.export romfs_isfpgabin
	.export romfs_isrom
	.export romfs_isflashbin
	.export romfs_isdrivebin
	.export romfs_stat
	.export romfs_firstnamechar
	.export romfs_isdesc
	.export romfs_volname
	.export romfs_write_clust

	.import lba
	.import cluster
	.importzp sectorptr
	.importzp clusterptr

	.import stat_cluster
	.import stat_length
	.import stat_type
	.importzp type_file, type_dir, type_vol, type_lfn, type_other

	.import romaddr
	.import vol_secperclus
	.importzp dirptr
	.importzp nameptr

	.import clusterbuf

	.import dev_read_sector


fs_romfs	= $01


	.bss

rootdir:	.res 4		; first sector of root directory
volnamelen:	.res 1		; length of volume name
volname:	.res 17		; volume name
eod:		.res 1		; end of directory flag


	.code

; return pointer and length to volume name
romfs_volname:
	ldy volnamelen
	ldax #volname
	rts



; read volume information
romfs_read_volid:
;	ldax #msg_reading_pvd
;	jsr debug_puts

	ldax #clusterbuf		; load primary volume descriptor
	stax sectorptr
	lda #0
	sta lba
	sta lba+1
	sta lba+2
	sta lba+3
	jsr dev_read_sector
	bcc @ok
@fail:
	sec
	rts
@ok:
	ldx #3			; check R0FS identifier
@compare:
	lda clusterbuf,x
	cmp r0fs,x
	bne @fail
	dex
	bpl @compare

;	ldax #msg_found_volume
;	jsr debug_puts

	ldx #15			; copy volume name
@copyvolname:
	lda clusterbuf+$10,x
	sta volname,x		; save volume name
;	jsr debug_put
	dex
	bpl @copyvolname
	lda clusterbuf + $0f	; save length
	sta volnamelen
;	jsr debug_crlf

	ldx volnamelen		; terminating 0
	lda #0
	sta volname,x

	ldx #3
:	lda clusterbuf + 4,x
	sta rootdir,x
	dex
	bpl :-

	lda #1
	sta vol_secperclus

	clc
	rts


; write cluster
romfs_write_clust:
	sec
	rts


; go to root directory
romfs_cdroot:
	ldx #3
:	lda rootdir,x
	sta cluster,x
	dex
	bpl :-
	clc
	rts


; change to boot directory
romfs_cdboot:
	ldax #bootdirname - $10
	stax nameptr
	jsr romfs_dir_first
	bcc @checkname
@error:
	sec
	rts

@checkname:
	jsr romfs_endofdir	; end of dir?
	beq @error

	jsr comparedirname	; check name
	beq @found

	jsr romfs_dir_next
	bcc @checkname
	rts

@found:
	ldy #7
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
romfs_dir_first:
	lda #0
	sta eod

	ldax #clusterbuf
	stax clusterptr
	jsr romfs_read_clust
	bcs @error
	ldax #clusterbuf
	stax dirptr
	clc
@error:
	rts


; go to the next entry
romfs_dir_next:
	ldy dirptr + 1
	lda dirptr
	clc
	adc #$20
	sta dirptr
	bcc :+
	iny
:	cpy #2 + >clusterbuf
	bne @done

	jsr romfs_next_clust
	jsr romfs_read_clust
	bcs @fail
	ldax #clusterbuf
	stax dirptr
@done:
	clc
@fail:
	rts


; check if dirptr points to the last entry
romfs_endofdir:
	ldy #0
	lda (dirptr),y
	rts


; return the first character of the filename
romfs_firstnamechar:
	ldy #$10
	lda (dirptr),y
	rts


; check if dir entry is xFPGA.BIN
romfs_isfpgabin:
	ldy #1
	lda (dirptr),y
	cmp #9
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldax #fpgabinname - $10
	stax nameptr
	jsr comparedirname
	bne @no
	; fall through

returnconfig:
	ldy #$10
	lda (dirptr),y
	and #$0f
	clc
	rts


; check if dir entry is xDESC.TXT
romfs_isdesc:
	ldy #1
	lda (dirptr),y
	cmp #9
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldax #descname - $10
	stax nameptr
	jsr comparedirname
	bne @no
	clc
	rts


; check if dir entry is flash code
romfs_isflashbin:
	ldy #1
	lda (dirptr),y
	cmp #9
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldax #flashbinname - $10
	stax nameptr
	jsr comparedirname
	bne @no
@return:
	clc
	rts


; check if dir entry is a rom image
romfs_isrom:
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
	ldax #romname - $10
	stax nameptr
	jsr comparedirname
	bne @no

	ldy #$12
	ldx #5
:	lda (dirptr),y
	sta romaddr,x
	dey
	dex
	bpl :-

	jmp returnconfig


romfs_isdrivebin:
	ldy #1
	lda (dirptr),y
	cmp #10
	beq @maybe
@no:
	sec
	rts
@maybe:
	ldax #drivebinname - $10
	stax nameptr
	jsr comparedirname
	bne @no
@return:
	clc
	rts



; compare dir entry name
; set nameptr to name - $10!
comparedirname:
	ldy #1
	lda (dirptr),y
	tax
	ldy #$10
comparedirname_start:			; call here with x and y set up
	lda (nameptr),y
	cmp #'?'			; any char matches
	beq @any
	cmp (dirptr),y
	bne @return
@any:
	iny
	dex
	bne comparedirname_start
@return:
	rts


; copy start cluster and length from dir entry
romfs_stat:
	ldy #4			; copy start cluster
:	lda (dirptr),y
	sta stat_cluster-4,y
	iny
	cpy #8
	bne :-

	ldy #8			; copy length
:	lda (dirptr),y
	sta stat_length-8,y
	iny
	cpy #12
	bne :-

	ldy #0			; check entry type
	lda (dirptr),y
	sta stat_type

	ldy #1			; return name length in y
	lda (dirptr),y
	tay

	ldax dirptr		; return pointer to name in a/x
	clc
	adc #$10
	bcc :+
	inx
:
@gotname:
	clc
	rts


; read the next cluster in the chain
romfs_next_clust:
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
romfs_read_clust:
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

dotdot:
	.byte ".."
bootdirname:
	.byte "BOOT"
fpgabinname:
	.byte "?FPGA.BIN"
romname:
	.byte "?R??????.BIN"
flashbinname:
	.byte "FLASH.BIN"
drivebinname:
	.byte "?DRIVE.BIN"
descname:
	.byte "?DESC.TXT"

r0fs:
	.byte "R0FS"

;msg_reading_pvd:
;	.byte "Reading Primary Volume Descriptor",13,10,0
;msg_found_volume:
;	.byte "Found ROMFS volume: ",0
