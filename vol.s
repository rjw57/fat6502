; this file acts as an abstraction layer between the file system
; specific routines and the boot code


	.include "drivecpu.i"

	.export vol_set_fs
	.export vol_read_ptable
	.export vol_cd
	.export vol_cdroot
	.export vol_dir_first
	.export vol_dir_next
	.export vol_next_clust
	.export vol_read_clust


	.importzp fs_fat12		; fat12/16/32 support
	.importzp fs_fat16
	.importzp fs_fat32

	.import fat_read_ptable
	.import fat_cd
	.import fat_cdroot
	.import fat_dir_first
	.import fat_dir_next
	.import fat_next_clust
	.import fat_read_clust


	.importzp fs_iso9660		; iso9660 support

	.import iso_read_ptable
	.import iso_cd
	.import iso_cdroot
	.import iso_dir_first
	.import iso_dir_next
	.import iso_next_clust
	.import iso_read_clust


	.bss

vectablesize	= 7

vector_table:		.res vectablesize * 2

vol_read_ptable_vector	= vector_table
vol_cd_vector		= vector_table + 2
vol_cdroot_vector	= vector_table + 4
vol_dir_first_vector	= vector_table + 6
vol_dir_next_vector	= vector_table + 8
vol_next_clust_vector	= vector_table + 10
vol_read_clust_vector	= vector_table + 12


	.rodata

fat_vectors:
	.word fat_read_ptable
	.word fat_cd
	.word fat_cdroot
	.word fat_dir_first
	.word fat_dir_next
	.word fat_next_clust
	.word fat_read_clust

iso_vectors:
	.word iso_read_ptable
	.word iso_cd
	.word iso_cdroot
	.word iso_dir_first
	.word iso_dir_next
	.word iso_next_clust
	.word iso_read_clust


	.code

vol_read_ptable:	jmp (vol_read_ptable_vector)
vol_cd:			jmp (vol_cd_vector)
vol_cdroot:		jmp (vol_cdroot_vector)
vol_dir_first:		jmp (vol_dir_first_vector)
vol_dir_next:		jmp (vol_dir_next_vector)
vol_next_clust:		jmp (vol_next_clust_vector)
vol_read_clust:		jmp (vol_read_clust_vector)


; call with filesystem identifier in A
vol_set_fs:
	cmp #fs_fat12
	beq @fat12
	cmp #fs_fat16
	beq @fat16
	cmp #fs_fat32
	beq @fat32
	cmp #fs_iso9660
	beq @iso9660
@fat12:
	sec
	rts

@fat16:
@fat32:
	ldx #0
@copyfat:
	lda fat_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyfat
	clc
	rts

@iso9660:
	ldx #0
@copyiso:
	lda iso_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyiso
	clc
	rts
