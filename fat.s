	.include "drivecpu.i"

	.export fat_cdroot
	.export fat_cdboot
	.export fat_dir_first, fat_dir_next
	.export fat12_next_clust, fat16_next_clust, fat32_next_clust
	.export fat_read_clust, fat_read_volid
	.export fat_endofdir
	.export fat_isfpgabin
	.export fat_isrom
	.export fat_isflashbin
	.export fat_isdrivebin
	.export fat12_stat, fat16_stat, fat32_stat
	.export fat_firstnamechar
	.export fat_isdesc
	.export fat_volname
	.export fat_write_clust

	.exportzp fs_fat12
	.exportzp fs_fat16
	.exportzp fs_fat32

	.importzp dirptr
	.importzp nameptr
	.importzp clusterptr
	.importzp ptr
	.importzp sectorptr

	.import stat_cluster
	.import stat_length

	.import dev_read_sector
	.import dev_write_sector

	.import clusterbuf

	.import lba
	.import cluster
	.import clusterbuf
	.import volsector

	.import vol_fstype
	.import vol_secperclus
	.import romaddr


fs_fat12	= $12
fs_fat16	= $16
fs_fat32	= $32
ptable		= clusterbuf + 446


	.bss

part_fat:	.res 4	; 32-bit start of fat
part_cstart:	.res 4	; 32-bit start of clusters
part_num:	.res 1	; partition number
part_rootdir:	.res 4	; 32-bit root directory address
part_rootdirstart:	.res 4	; start sector for FAT12/FAT16 root directory
scount:		.res 1	; number of sectors to read
fatbuf:		.res 512
fatcache:	.res 4	; 32-bit currently cached fat sector
fat12tmp:	.res 2	; work area to compute fat 12 sectors
fat12half:	.res 1	; flag that tells us if we should start with the
			; high nybble ($80) or low nybble ($00)
fat12byte:	.res 1	; temporary storage for current fat 12 byte
fat12cluster:	.res 1  ; more temporary storage
fat12fatflag:	.res 1	; flag that tells us to read the next fat sector
volnamelen:	.res 1	; length of volume name
volname:	.res 12	; volume name
rctemp:		.res 1	; ugly, ugly fat16


	.code

; return pointer and length to volume name
fat_volname:
	ldy volnamelen
	ldax volname
	rts


; load the root directory
fat_cdroot:
	lda part_rootdir
	sta cluster
	lda part_rootdir+1
	sta cluster+1
	lda part_rootdir+2
	sta cluster+2
	lda part_rootdir+3
	sta cluster+3
	clc
	rts


; return the first char of the filename
fat_firstnamechar:
	; w00t, same code as below


; 0 if dirptr points to end of dir
fat_endofdir:
	ldy #0			; check for end of dir
	lda (dirptr),y
	rts


; copy start cluster and length from dirptr entry
fat12_stat:
fat16_stat:
	lda #0			; upper half is 0
	sta stat_cluster+2
	sta stat_cluster+3
	jmp stat

fat32_stat:
	ldy #$14		; copy the start cluster
	lda (dirptr),y
	sta stat_cluster+2
	iny
	lda (dirptr),y
	sta stat_cluster+3

stat:
	ldy #$1a
	lda (dirptr),y
	sta stat_cluster
	iny
	lda (dirptr),y
	sta stat_cluster+1

	ldy #$1f		; copy the length
	ldx #3
@copylength:
	lda (dirptr),y
	sta stat_length,x
	dey
	dex
	bpl @copylength

	clc
	rts


; check if the dir entry pointed to by dirptr is an FPGA config file
; return config number in A
; does NOT verify that the first char is a digit!
fat_isfpgabin:
	ldax fpganame
	stax nameptr
compare:
	jsr comparedirname
	beq @yes
	sec
	rts
@yes:
returnconfig:
	lda (dirptr),y
	and #$0f
	clc
	rts


; check if it's a drive binary
fat_isdrivebin:
	ldax drivename
	stax nameptr
	jmp compare


; check if it's a flash binary
fat_isflashbin:
	ldax flashname
	stax nameptr
	jmp compare


; check if it's a description file
fat_isdesc:
	ldax descname
	stax nameptr
	jmp compare


; check if the dir entry pointed to by dirptr is a ROM image file
; copy ascii image address to romaddr and return config number in A
; does NOT verify that the first char is a digit!
fat_isrom:
	ldax romname
	stax nameptr
	jsr comparedirname
	beq @yes

	sec
	rts
@yes:
	ldy #7
	ldx #5
@copy:
	lda (dirptr),y
	sta romaddr,x
	dey
	dex
	bpl @copy
	dey
	beq returnconfig


; change directory
; needs the first cluster of the current dir in cluster
; and the name of the dir to change to in nameptr
; returns the new dir address in cluster or carry set on error
fat_cdboot:
	ldax bootdirname
	stax nameptr
	jsr fat_dir_first
	bcs @error

@checkname:
	ldy #0

	lda (dirptr),y
	beq @error		; if it's 0 we reached the end of the dir
	cmp #$e5		; if it's $e5 it's a deleted file
	beq @next

	ldy #11			; check attrib flags
	lda (dirptr),y
	and #$10		; bit 4 is the dir flag
	beq @next

	jsr comparedirname	; compare name
	beq @founddir

@next:
	jsr fat_dir_next	; grab the next entry
	bcc @checkname
	
@error:
	sec
	rts

@founddir:
	ldy #$1a		; we found the directory, new cluster
	lda (dirptr),y		; address
	sta cluster
	iny
	lda (dirptr),y
	sta cluster+1

	lda vol_fstype
	cmp #fs_fat32
	bne @fat16or12

	ldy #$14
	lda (dirptr),y
	sta cluster+2
	iny
	lda (dirptr),y
	sta cluster+3
	clc
	rts

@fat16or12:
	lda #0
	sta cluster+2
	sta cluster+3
	clc
	rts


; compare two strings at dirptr and nameptr
comparedirname:
	ldy #10
@compare:
	lda (nameptr),y
	cmp #'?'
	beq @any
	cmp (dirptr),y
	bne @exit
@any:
	dey
	bpl @compare
	lda #0
@exit:
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


; find the first dir entry
fat_dir_first:
	ldax clusterbuf
	stax clusterptr
	jsr fat_read_clust	; load dir cluster into buffer
	bcc fat_dir_ok

fat_dir_error:
	sec
	rts

fat_dir_ok:
	lda #<clusterbuf	; point to beginning of dir
	sta dirptr
	lda #>clusterbuf
	sta dirptr+1

fat_dir_return:
	clc
	rts



fat_dir_next:
	lda dirptr		; advance pointer 32 bytes to the
	clc			; next entry
	adc #32
	sta dirptr
	bcc @skip
	inc dirptr+1
@skip:
	lda vol_secperclus	; check if we've parsed the whole
	asl			; cluster
	;clc
	adc #>clusterbuf
	cmp dirptr+1
	bne fat_dir_return

	jsr fat_next_clust	; next cluster in chain
	beq fat_dir_error	; premature end of directory
	bcs fat_dir_error
	ldax clusterbuf
	stax clusterptr
	jsr fat_read_clust	; load cluster into buffer
	bcc fat_dir_ok
	bcs fat_dir_error


next_dir_entry:
@return:
	rts


fat12_next_byte:
	ldx fat12tmp
	lda fat12tmp+1
	bne @upperhalf

	lda fatbuf,x		; get byte from lower half of FAT sector
	jmp @getnext

@upperhalf:
	lda fatbuf + 256,x	; get byte from upper half of FAT sector

@getnext:
	sta fat12byte
	inc fat12tmp		; increment our byte offset to the FAT
	bne @done
	inc fat12tmp+1
	lda fat12tmp+1
	cmp #$02		; check if we're past the end of the sector
	bcc @done
	
	bit fat12fatflag	; should we read the next fat sector ?
	bmi @done
	
	lda #$00		; zero out or fat sector offset
	sta fat12tmp+1
	
	inc lba			; read in the next sector
	bne @skiplb1
	inc lba+1
@skiplb1:
	lda #<fatbuf		; repeating a bit of code here - maybe this
	sta sectorptr           ; should be a subroutine
	lda #>fatbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcs @error

	ldx #3			; mark this sector as cached
:	lda lba,x
	sta fatcache,x
	dex
	bpl :-
	
@done:
	lda fat12byte
	clc
	rts

@error:
	sec
	rts


fat12_next_clust:
				; We have to multiply the cluster number
				; Times 1.5 to get a byte offset into the FAT
	clc
	lda cluster+1
	lsr			; Divide by two first
	sta fat12tmp+1
	lda cluster
	ror
	sta fat12tmp
	lda #$00
	ror
	sta fat12half		; Set our flag to know if we have to start
				; on the high nybble
	;clc
	lda cluster		; Add the result of the division by two to
	adc fat12tmp		; the original cluster number and we get
	sta fat12tmp		; cluster*1.5 + our 'half' flag
	lda cluster+1
	adc fat12tmp+1
	sta fat12tmp+1		; We now have the full byte offset in fat12tmp
	
	lsr			; bits 15-9 contain our fat sector number
	sta lba			; so shift them in place
	lda #$00
	sta lba+1
	sta lba+2
	sta lba+3
	
	lda fat12tmp+1		; Strip the highest 7 bits and we get a
	and #$01		; byte offset into the sector
	sta fat12tmp+1			
	
	jsr addfatstart

	jsr isfatcached
	beq @iscached

	lda #<fatbuf
	sta sectorptr
	lda #>fatbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcs @error

	ldx #3			; mark this sector as cached
:	lda lba,x
	sta fatcache,x
	dex
	bpl :-

@iscached:
	lda #$7f		; set flag to read the next sector if
	sta fat12fatflag	; necessary
	jsr fat12_next_byte	; Get the current byte from the FAT
	bcs @error
	sta fat12cluster
	
	inc fat12fatflag	; don't read the next sector this time
	jsr fat12_next_byte	; Next byte
	bcs @error

	bit fat12half		; test nybble flag
	bmi @nybswap
	and #$0f		; Flag not set so just mask out the 4
	sta cluster+1		; high bits of the second byte
	lda fat12cluster
	sta cluster
	jmp @checklast
	
@nybswap:
	lsr
	ror fat12cluster	; Flag set, so rotate things into place
	lsr
	ror fat12cluster
	lsr
	ror fat12cluster
	lsr
	ror fat12cluster
	sta cluster+1
	lda fat12cluster
	sta cluster
	
@checklast:
	lda cluster+1
	cmp #$0f
	bne @done
	lda cluster
	and #$f0
	cmp #$f0
	
@done:
	clc
	rts

@error:
	sec
	rts


fat_next_clust:
	lda vol_fstype
	cmp #fs_fat12
	bne @testfat32
	jmp fat12_next_clust	; We've got range
@testfat32:
	cmp #fs_fat32
	beq fat32_next_clust


; find the next linked cluster from the FAT
fat16_next_clust:
	lda cluster+1		; there are 2 bytes for each entry
	sta lba			; in the FAT this gives us 256
	lda cluster+2		; entries in every FAT sector so
	sta lba+1		; bits 31..8 of the current cluster
	lda cluster+3		; address gives us the sector to
	sta lba+2		; read
	lda #0
	sta lba+3

	jsr addfatstart		; fat += part-fat

	jsr isfatcached		; check if fat is already in buffer
	beq @iscached

	lda #<fatbuf
	sta sectorptr
	lda #>fatbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcs @error

	ldx #3			; mark this sector as cached
:	lda lba,x
	sta fatcache,x
	dex
	bpl :-

@iscached:
	lda cluster		; offset = cluster<<1
	asl
	tax
	bcs @upperhalf

	lda fatbuf,x		; copy new cluster address
	sta cluster
	inx
	lda fatbuf,x
	sta cluster+1

	jmp @checkeoc

@upperhalf:
	lda fatbuf + 256,x
	sta cluster
	inx
	lda fatbuf + 256,x
	sta cluster+1

@checkeoc:
	lda #0		; this is FAT*16*
	sta cluster+2
	sta cluster+3

	lda cluster+1		; check for end of cluster chain
	cmp #$ff
	bne @done

	lda cluster
	and #$f0		; the 4 least significant bits are ignored
	cmp #$f0

@done:
	clc
	rts

@error:
	sec
	rts


fat32_next_clust:
	lda cluster+1		; there are 4 bytes for each entry
	sta lba			; in the FAT this gives us 128 entries
	lda cluster+2		; in every FAT sector so bits 31..7 of
	sta lba+1		; the current cluster address gives us
	lda cluster+3		; the FAT sector to read
	sta lba+2
	lda #0
	sta lba+3

	lda cluster		; lba = cluster>>7
	asl
	rol lba
	rol lba+1
	rol lba+2
	rol lba+3

	jsr addfatstart		; fat += part_fat

	jsr isfatcached		; check if fat is already in buffer
	beq @iscached

	lda #<fatbuf
	sta sectorptr
	lda #>fatbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcs @error

	ldx #3			; mark this sector as cached
:	lda lba,x
	sta fatcache,x
	dex
	bpl :-

@iscached:
	lda cluster		; offset = (cluster & 127)<<2
	asl
	asl
	tax
	bcs @upperhalf

	lda fatbuf,x		; copy new cluster address
	sta cluster
	inx
	lda fatbuf,x
	sta cluster+1
	inx
	lda fatbuf,x
	sta cluster+2
	inx
	lda fatbuf,x
	sta cluster+3

	jmp @checkeoc

@upperhalf:
	lda fatbuf + 256,x
	sta cluster
	inx
	lda fatbuf + 256,x
	sta cluster+1
	inx
	lda fatbuf + 256,x
	sta cluster+2
	inx
	lda fatbuf + 256,x
	sta cluster+3

@checkeoc:
	lda cluster+1		; check for end of cluster chain
	and cluster+2
	and cluster+3
	cmp #$ff
	bne @done

	lda cluster
	and #$f0		; the 4 least significant bits are ignored
	cmp #$f0

@done:
	clc
	rts

@error:
	sec
	rts


; lba += start of fat
addfatstart:
	clc
	lda lba
	adc part_fat
	sta lba
	lda lba+1
	adc part_fat+1
	sta lba+1
	lda lba+2
	adc part_fat+2
	sta lba+2
	lda lba+3
	adc part_fat+3
	sta lba+3
	rts


; check if fat is already cached
isfatcached:
	ldx #0
:	lda lba,x
	cmp fatcache,x
	bne @no
	inx
	cpx #4
	bne :-
@no:
	rts


; load the specified cluster to memory
fat_read_clust:
	jsr clustertolba	; calculate lba address, sets scount

	lda clusterptr		; load to cluster buffer
	sta sectorptr
	lda clusterptr+1
	sta sectorptr+1

@readnext:
	jsr dev_read_sector	; write the sector
	bcs @error

	inc lba			; next sector
	bne @done
	inc lba+1
	bne @done
	inc lba+2
	bne @done
	inc lba+3
@done:
	dec scount
	bne @readnext

	lda sectorptr		; update cluster pointer
	sta clusterptr
	lda sectorptr+1
	sta clusterptr+1

	clc
@error:
	rts


; write cluster sector by sector
fat_write_clust:
	jsr clustertolba	; calculate lba address, sets scount

	lda clusterptr		; load to cluster buffer
	sta sectorptr
	lda clusterptr+1
	sta sectorptr+1

@readnext:
	jsr dev_write_sector	; write the sector
	bcs @error

	inc lba			; next sector
	bne @done
	inc lba+1
	bne @done
	inc lba+2
	bne @done
	inc lba+3
@done:
	dec scount
	bne @readnext

	lda sectorptr		; update cluster pointer
	sta clusterptr
	lda sectorptr+1
	sta clusterptr+1

	clc
@error:
	rts


; calculate lba address of cluster
; with ugly, ugly special case for FAT12/16 root directory
; sets scount
clustertolba:
	lda cluster		; lba = cluster * secperclus + part_cstart
	sta lba
	sta rctemp
	lda cluster+1
	sta lba+1
	ora rctemp
	sta rctemp
	lda cluster+2
	sta lba+2
	ora rctemp
	sta rctemp
	lda cluster+3
	sta lba+3
	ora rctemp
	bne @notclusterzero

	lda vol_fstype
	cmp #fs_fat32
	beq @notclusterzero

	lda part_rootdirstart	; fat12/16 
	sta lba
	lda part_rootdirstart+1
	sta lba+1
	lda part_rootdirstart+2
	sta lba+2
	lda part_rootdirstart+3
	sta lba+3

	lda #16			; assuming 512 rootdir entries for FAT16. ugly, ugly
	bne @done

@notclusterzero:
	lda vol_secperclus	; multiply cluster address by number of
@shift:
	lsr			; sectors per cluster. this number is a
	bcs @shifted		; power of two so we'll just shift.
	asl lba
	rol lba+1
	rol lba+2
	rol lba+3
	jmp @shift
@shifted:

	clc			; add start of clusters
	lda lba
	adc part_cstart
	sta lba
	lda lba+1
	adc part_cstart+1
	sta lba+1
	lda lba+2
	adc part_cstart+2
	sta lba+2
	lda lba+3
	adc part_cstart+3
	;sta lba+3

	; we should now have the correct cluster in the lba address

	lda vol_secperclus	; number of sectors to read
@done:
	sta scount
	rts


; read the volume ID
fat_read_volid:
	ldx #3
:	lda volsector,x
	sta lba,x
	dex
	bpl :-
	lda #<clusterbuf
	sta sectorptr
	lda #>clusterbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcc @checksig
@error:
	sec
	rts
@checksig:
	jsr check_signature
	bcs @error

	jsr checkgeom
	bne @error

	jsr findfatstart

	lda vol_fstype
	cmp #fs_fat32
	beq @fat32

	asl clusterbuf + $16	; multiply fatsize by two
	rol clusterbuf + $17	; possible overflow?
	bcs @error

	;clc
	lda part_fat		; skip fats to find rootdir *sector*
	adc clusterbuf + $16
	sta part_rootdirstart
	lda part_fat + 1
	adc clusterbuf + $17
	sta part_rootdirstart + 1
	lda part_fat + 2
	adc #0
	sta part_rootdirstart + 2
	lda part_fat + 3
	adc #0
	sta part_rootdirstart + 3

	ldx #4		; divide rootdirentries by 16 to
@div16:
	lsr clusterbuf + $12	; get the number of blocks
	ror clusterbuf + $11
	dex
	bne @div16
	bcs @error

	;clc
	lda part_rootdirstart	; skip rootdir to find start of
	adc clusterbuf + $11	; clusters
	sta part_cstart
	lda part_rootdirstart + 1
	adc clusterbuf + $12
	sta part_cstart + 1
	lda part_rootdirstart + 2
	adc #0
	sta part_cstart + 2
	lda part_rootdirstart + 3
	adc #0
	sta part_cstart + 3

	ldx #3			; root directory is always at cluster 0
	lda #0
:	sta part_rootdir,x
	dex
	bpl :-

	jmp subcluster


@fat32:
	lda clusterbuf + $2c	; store address of root directory
	sta part_rootdir
	lda clusterbuf + $2d
	sta part_rootdir+1
	lda clusterbuf + $2e
	sta part_rootdir+2
	lda clusterbuf + $2f
	sta part_rootdir+3

	; find start of clusters

	asl clusterbuf + $24	; multiply FAT size by two
	rol clusterbuf + $25
	rol clusterbuf + $26
	rol clusterbuf + $27

	clc			; then skip them
	lda part_fat
	adc clusterbuf + $24
	sta part_cstart
	lda part_fat+1
	adc clusterbuf + $25
	sta part_cstart+1
	lda part_fat+2
	adc clusterbuf + $26
	sta part_cstart+2
	lda part_fat+3
	adc clusterbuf + $27
	sta part_cstart+3

subcluster:
	ldx #2			; subtract two clusters to compensate
:	sec			; for reserved values 0 and 1
	lda part_cstart
	sbc vol_secperclus
	sta part_cstart
	lda part_cstart+1
	sbc #0
	sta part_cstart+1
	lda part_cstart+2
	sbc #0
	sta part_cstart+2
	lda part_cstart+3
	sbc #0
	sta part_cstart+3
	dex
	bne :-

	; find and save volume name

	lda #0
	sta volnamelen

	jsr fat_cdroot
	jsr fat_dir_first
@check:
	jsr fat_endofdir
	beq @end
	ldy #11
	lda (dirptr),y
	and #8
	beq @end

	sty volnamelen
	dey
:	lda (dirptr),y
	cmp #' '
	bne @copy
	dec volnamelen
	dey
	bpl :-
	bmi @end		; empty name

@copy:
:	lda (dirptr),y
	sta volname,y
	dey
	bpl :-

@end:
	ldy volnamelen		; terminating zero
	lda #0
	sta volname,y
	clc
	rts


findfatstart:
	clc			; first skip reserved sectors
	lda lba
	adc clusterbuf + $0e
	sta part_fat
	lda lba+1
	adc clusterbuf + $0f
	sta part_fat+1
	lda lba+2
	adc #0
	sta part_fat+2
	lda lba+3
	adc #0
	sta part_fat+3
	rts


checkgeom:
	lda clusterbuf + $0b	; make sure sector size is 512
	bne @checkfail
	lda clusterbuf + $0c
	cmp #2
	bne @checkfail

	lda clusterbuf + $10	; make sure there are 2 FATs
	cmp #2
	bne @checkfail

	lda clusterbuf + $0d	; number of sectors per cluster
	sta vol_secperclus
	and #$80		; we can't handle 64K clusters
@checkfail:
	rts


; check for signature bytes
check_signature:
	lda clusterbuf + $1fe
	cmp #$55
	bne @error

	lda clusterbuf + $1ff
	cmp #$aa
	bne @error

	clc
	rts
@error:
	sec
	rts


	.rodata

msg_foundfat12:
	.byte "Found FAT12 partition number ",0
msg_foundfat16:
	.byte "Found FAT16 partition number ",0
msg_foundfat32:
	.byte "Found FAT32 partition number ",0

bootdirname:
	.byte "BOOT    ","   "
fpganame:
	.byte "?FPGA   ","BIN"
romname:
	.byte "?R??????","BIN"
flashname:
	.byte "FLASH   ","BIN"
drivename:
	.byte "?DRIVE  ","BIN"
descname:
	.byte "?DESC   ","TXT"
