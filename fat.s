	.include "drivecpu.i"

	.export fat12_cdroot, fat16_cdroot, fat32_cdroot
	.export fat_cd, fat_dir_first, fat_dir_next
	.export fat12_next_clust, fat16_next_clust, fat32_next_clust
	.export fat_read_clust, fat_read_ptable
	.export cluster
	.exportzp fs_fat12
	.exportzp fs_fat16
	.exportzp fs_fat32

	.importzp dirptr
	.importzp nameptr
	.importzp ptr
	.importzp sectorptr

	.import dev_read_sector
	.import comparedirname

	.import clusterbuf

	.import lba

	.import part_fstype
	.import part_secperclus

	.import debug_put
	.import debug_puts
	.import debug_puthex
	.import debug_putdigit
	.import debug_crlf
	.import dstr_crlf
	.import dstr_dircluster
	.import dstr_foundfat12
	.import dstr_foundfat16
	.import dstr_foundfat32


fs_fat12	= $12
fs_fat16	= $16
fs_fat32	= $32
ptable		= sectorbuf + 446


	.bss

part_fat:	.res 4	; 32-bit start of fat
part_cstart:	.res 4	; 32-bit start of clusters
part_num:	.res 1	; partition number
part_start:	.res 4	; 32-bit LBA start address of active partition
part_rootdir:	.res 4	; 32-bit root directory address
scount:		.res 1	; number of sectors to read
cluster:	.res 4	; 32-bit cluster address
			; multiply by number of sectors per cluster
			; add start of clusters
			; and you get the logical block address
sectorbuf:	.res 512
fatbuf:		.res 512
fatcache:	.res 4	; 32-bit currently cached fat sector


	.code

; load the root directory
fat12_cdroot:
fat16_cdroot:
	lda #0
	sta cluster
	sta cluster+1
	sta cluster+2
	sta cluster+3
	clc
	rts

fat32_cdroot:
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


; change directory
; needs the first cluster of the current dir in cluster
; and the name of the dir to change to in nameptr
; returns the new dir address in cluster or carry set on error
fat_cd:
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

	dey			; compare name
	jsr comparedirname
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

	lda part_fstype
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


; find the first dir entry
fat_dir_first:
	;dputs dstr_dircluster
	;dputnum32 cluster
	;dputs dstr_crlf

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
	lda part_secperclus	; check if we've parsed the whole
	asl			; cluster
	;clc
	adc #>clusterbuf
	cmp dirptr+1
	bne fat_dir_return

	jsr fat_next_clust	; next cluster in chain
	beq fat_dir_error	; premature end of directory
	bcs fat_dir_error
	jsr fat_read_clust	; load cluster into buffer
	bcc fat_dir_ok
	bcs fat_dir_error


next_dir_entry:
@return:
	rts


fat12_next_clust:
	inc cluster		; fixme. badly.
	bne @done
	inc cluster+1
	bne @done
	inc cluster+2
	bne @done
	inc cluster+3
@done:
	clc
	rts


fat_next_clust:
	lda part_fstype
	cmp #fs_fat12
	beq fat12_next_clust
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
	and #$f0		; the 3 least significant bits are ignored
	cmp #$f0

@done:
	clc
	rts

@error:
	sec
	rts


fat32_next_clust:
	lda cluster+1		; there are 4 bytes for each entry
	sta lba		; in the FAT this gives us 128 entries
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
	and #$f8		; the 3 least significant bits are ignored
	cmp #$f8

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
; with ugly, ugly special case for FAT12/16 root directory
	.bss
rctemp:	.res 1			; ugly, ugly fat16
	.code

fat_read_clust:
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

	lda part_fstype
	cmp #fs_fat32
	beq @notclusterzero

	lda part_rootdir	; fat12/16 
	sta lba
	lda part_rootdir+1
	sta lba+1
	lda part_rootdir+2
	sta lba+2
	lda part_rootdir+3
	sta lba+3

	lda #16			; assuming 512 rootdir entries for FAT16. ugly, ugly
	jmp @readsectors

@notclusterzero:
	lda part_secperclus	; multiply cluster address by number of
@shift:
	lsr		; sectors per cluster. this number is a
	bcs @shifted		; power of two so we'll just shift.
	asl lba
	rol lba+1
	rol lba+2
	rol lba+3
	jmp @shift
@shifted:

	clc		; add start of clusters
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

	lda part_secperclus	; number of sectors to read
@readsectors:
	sta scount

	lda #<clusterbuf	; load to cluster buffer
	sta sectorptr
	lda #>clusterbuf
	sta sectorptr+1

@readnext:
	jsr dev_read_sector
	bcs @error

	inc lba		; next sector
	bne @done
	inc lba+1
	bne @done
	inc lba+2
	bne @done
	inc lba+3
@done:
	dec scount
	bne @readnext

	clc
	rts

@error:
	sec
	rts


; reads the partition table and finds the first FAT32 partition
fat_read_ptable:
	lda #0		; we'll find the partition
	sta lba		; table in sector 0
	sta lba+1
	sta lba+2
	sta lba+3

	lda #<sectorbuf
	sta sectorptr
	lda #>sectorbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcs @error

	jsr check_signature
	bcs @error

	lda #<ptable		; pointer to the partition table
	sta ptr
	lda #>ptable
	sta ptr+1
	ldx #0

	ldy #4
@checktype:
	lda (ptr),y		; check file system type
	cmp #$01
	beq foundfat12		; fat12 uses $01
	cmp #$04		; fat16 uses $04, $06, or $0e
	beq foundfat16
	cmp #$06
	beq foundfat16
	cmp #$0e
	beq foundfat16
	cmp #$0b		; fat32 uses $0b or $0c
	beq _foundfat32
	cmp #$0c
	beq _foundfat32

	lda ptr
	clc
	adc #16
	sta ptr

	inx
	cpx #4
	bne @checktype

@error:
	sec
	rts

_foundfat32:
	jmp foundfat32		; branch range. bah.


foundfat12:
	inx
	stx part_num

	dputs dstr_foundfat12
	txa
	dputdigit
	dputs dstr_crlf

	lda #fs_fat12		; store partition type
	sta part_fstype

	jmp cont12		; continue as if FAT16

foundfat16:
	inx
	stx part_num		; save partition number

	dputs dstr_foundfat16
	txa
	dputdigit
	dputs dstr_crlf

	lda #fs_fat16		; store partition type
	sta part_fstype

cont12:
	jsr loadvolid
	bcc @noerror

@error:
	sec
	rts
@noerror:
	jsr checkgeom
	bne @error

	jsr findfatstart

	asl sectorbuf + $16	; multiply fatsize by two
	rol sectorbuf + $17	; possible overflow?
	bcs @error

	;clc
	lda part_fat		; skip fats to find rootdir *sector*
	adc sectorbuf + $16
	sta part_rootdir
	lda part_fat + 1
	adc sectorbuf + $17
	sta part_rootdir + 1
	lda part_fat + 2
	adc #0
	sta part_rootdir + 2
	lda part_fat + 3
	adc #0
	sta part_rootdir + 3

	ldx #4		; divide rootdirentries by 16 to
@div16:
	lsr sectorbuf + $12	; get the number of blocks
	ror sectorbuf + $11
	dex
	bne @div16
	bcs @error

	;clc
	lda part_rootdir	; skip rootdir to find start of
	adc sectorbuf + $11	; clusters
	sta part_cstart
	lda part_rootdir + 1
	adc sectorbuf + $12
	sta part_cstart + 1
	lda part_rootdir + 2
	adc #0
	sta part_cstart + 2
	lda part_rootdir + 3
	adc #0
	sta part_cstart + 3

	jmp subcluster


foundfat32:
	inx
	stx part_num		; save partition number

	dputs dstr_foundfat32
	txa
	dputdigit
	dputs dstr_crlf

	lda #fs_fat32		; store partition type
	sta part_fstype

	jsr loadvolid
	bcc @noerror

@error:
	sec
	rts
@noerror:
	jsr checkgeom
	bne @error

	jsr findfatstart

	lda sectorbuf + $2c	; store address of root directory
	sta part_rootdir
	lda sectorbuf + $2d
	sta part_rootdir+1
	lda sectorbuf + $2e
	sta part_rootdir+2
	lda sectorbuf + $2f
	sta part_rootdir+3

	; find start of clusters

	asl sectorbuf + $24	; multiply FAT size by two
	rol sectorbuf + $25
	rol sectorbuf + $26
	rol sectorbuf + $27

	clc		; then skip them
	lda part_fat
	adc sectorbuf + $24
	sta part_cstart
	lda part_fat+1
	adc sectorbuf + $25
	sta part_cstart+1
	lda part_fat+2
	adc sectorbuf + $26
	sta part_cstart+2
	lda part_fat+3
	adc sectorbuf + $27
	sta part_cstart+3

subcluster:
	ldx #2		; subtract two clusters to compensate
@subcluster:
	sec		; for reserved values 0 and 1
	lda part_cstart
	sbc part_secperclus
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
	bne @subcluster

	; ok, we have now initialized everything we need
	; to load files from the partition

	clc
	rts


loadvolid:
	ldy #8		; grab the address of the volume ID
	lda (ptr),y
	sta lba
	sta part_start
	iny
	lda (ptr),y
	sta lba+1
	sta part_start+1
	iny
	lda (ptr),y
	sta lba+2
	sta part_start+2
	iny
	lda (ptr),y
	sta lba+3
	sta part_start+3

	lda #<sectorbuf
	sta sectorptr
	lda #>sectorbuf
	sta sectorptr+1

	jsr dev_read_sector
	bcs @error

	jsr check_signature	; check for $aa55
	bcs @error

	clc
@error:
	rts


findfatstart:
	clc		; first skip reserved sectors
	lda lba
	adc sectorbuf + $0e
	sta part_fat
	lda lba+1
	adc sectorbuf + $0f
	sta part_fat+1
	lda lba+2
	adc #0
	sta part_fat+2
	lda lba+3
	adc #0
	sta part_fat+3
	rts


checkgeom:
	lda sectorbuf + $0b	; make sure sector size is 512
	bne @checkfail
	lda sectorbuf + $0c
	cmp #2
	bne @checkfail

	lda sectorbuf + $10	; make sure there are 2 FATs
	cmp #2
	bne @checkfail

	lda sectorbuf + $0d	; number of sectors per cluster
	sta part_secperclus
	and #$80		; we can't handle 64K clusters
@checkfail:
	rts


; check for signature bytes
check_signature:
	lda sectorbuf + $1fe
	cmp #$55
	bne @error

	lda sectorbuf + $1ff
	cmp #$aa
	bne @error

	clc
	rts
@error:
	sec
	rts
