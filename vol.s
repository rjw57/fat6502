; this file acts as an abstraction layer between the file system
; specific routines and the boot code


	.include "drivecpu.i"

	.export vol_set_fs
	.export vol_read_ptable
	.export vol_cdboot
	.export vol_cdroot
	.export vol_dir_first
	.export vol_dir_next
	.export vol_next_clust
	.export vol_read_clust
	.export vol_endofdir
	.export vol_isfpgabin
	.export vol_isrom
	.export vol_isflashbin
	.export vol_isdrivebin
	.export vol_stat
	.export vol_firstnamechar

	.export romaddr
	.export stat_length
	.export stat_cluster
	.export vol_fstype
	.export vol_secperclus
	.export cluster
	.exportzp dirptr, nameptr, clusterptr

	.importzp fs_fat12		; fat12/16/32 support
	.importzp fs_fat16
	.importzp fs_fat32

	.import fat_read_ptable
	.import fat_cdboot
	.import fat12_cdroot, fat16_cdroot, fat32_cdroot
	.import fat_dir_first
	.import fat_dir_next
	.import fat12_next_clust, fat16_next_clust, fat32_next_clust
	.import fat_read_clust
	.import fat_endofdir
	.import fat_isfpgabin
	.import fat_isrom
	.import fat_isflashbin
	.import fat_isdrivebin
	.import fat12_stat, fat16_stat, fat32_stat
	.import fat_firstnamechar


	.importzp fs_iso9660		; iso9660 support

	.import iso_read_ptable
	.import iso_cdboot
	.import iso_cdroot
	.import iso_dir_first
	.import iso_dir_next
	.import iso_next_clust
	.import iso_read_clust
	.import iso_endofdir
	.import iso_isfpgabin
	.import iso_isrom
	.import iso_isflashbin
	.import iso_isdrivebin
	.import iso_stat
	.import iso_firstnamechar


	.zeropage

dirptr:		.res 2	; directory pointer
nameptr:	.res 2	; name pointer
clusterptr:	.res 2	; custer buffer


	.bss

	.align 2
vectablesize		= 14
vector_table:		.res vectablesize * 2
vol_read_ptable_vector	= vector_table
vol_cdboot_vector	= vector_table + 2
vol_cdroot_vector	= vector_table + 4
vol_dir_first_vector	= vector_table + 6
vol_dir_next_vector	= vector_table + 8
vol_next_clust_vector	= vector_table + 10
vol_read_clust_vector	= vector_table + 12
vol_endofdir_vector	= vector_table + 14
vol_isfpgabin_vector	= vector_table + 16
vol_isrom_vector	= vector_table + 18
vol_isflashbin_vector	= vector_table + 20
vol_isdrivebin_vector	= vector_table + 22
vol_stat_vector		= vector_table + 24
vol_firstnamechar_vector= vector_table + 26

romaddr:		.res 6
stat_length:		.res 4
stat_cluster:		.res 4
vol_fstype:		.res 1
vol_secperclus:		.res 1	; number of 512-byte sectors per cluster
cluster:		.res 4	; 32-bit cluster address


	.rodata

fat12_vectors:
	.word fat_read_ptable
	.word fat_cdboot
	.word fat12_cdroot
	.word fat_dir_first
	.word fat_dir_next
	.word fat12_next_clust
	.word fat_read_clust
	.word fat_endofdir
	.word fat_isfpgabin
	.word fat_isrom
	.word fat_isflashbin
	.word fat_isdrivebin
	.word fat12_stat
	.word fat_firstnamechar

fat16_vectors:
	.word fat_read_ptable
	.word fat_cdboot
	.word fat16_cdroot
	.word fat_dir_first
	.word fat_dir_next
	.word fat16_next_clust
	.word fat_read_clust
	.word fat_endofdir
	.word fat_isfpgabin
	.word fat_isrom
	.word fat_isflashbin
	.word fat_isdrivebin
	.word fat16_stat
	.word fat_firstnamechar

fat32_vectors:
	.word fat_read_ptable
	.word fat_cdboot
	.word fat32_cdroot
	.word fat_dir_first
	.word fat_dir_next
	.word fat32_next_clust
	.word fat_read_clust
	.word fat_endofdir
	.word fat_isfpgabin
	.word fat_isrom
	.word fat_isflashbin
	.word fat_isdrivebin
	.word fat32_stat
	.word fat_firstnamechar

iso_vectors:
	.word iso_read_ptable
	.word iso_cdboot
	.word iso_cdroot
	.word iso_dir_first
	.word iso_dir_next
	.word iso_next_clust
	.word iso_read_clust
	.word iso_endofdir
	.word iso_isfpgabin
	.word iso_isrom
	.word iso_isflashbin
	.word iso_isdrivebin
	.word iso_stat
	.word iso_firstnamechar


	.code

vol_read_ptable:	jmp (vol_read_ptable_vector)
vol_cdboot:		jmp (vol_cdboot_vector)
vol_cdroot:		jmp (vol_cdroot_vector)
vol_dir_first:		jmp (vol_dir_first_vector)
vol_dir_next:		jmp (vol_dir_next_vector)
vol_next_clust:		jmp (vol_next_clust_vector)
vol_read_clust:		jmp (vol_read_clust_vector)
vol_endofdir:		jmp (vol_endofdir_vector)
vol_isfpgabin:		jmp (vol_isfpgabin_vector)
vol_isrom:		jmp (vol_isrom_vector)
vol_isflashbin:		jmp (vol_isflashbin_vector)
vol_isdrivebin:		jmp (vol_isdrivebin_vector)
vol_stat:		jmp (vol_stat_vector)
vol_firstnamechar:	jmp (vol_firstnamechar_vector)


; call with filesystem identifier in A
vol_set_fs:
	sta vol_fstype
	cmp #fs_fat12
	beq fat12
	cmp #fs_fat16
	beq fat16
	cmp #fs_fat32
	beq fat32
	cmp #fs_iso9660
	beq iso9660
	sec
	rts

fat12:
	ldx #0
@copyfat:
	lda fat12_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyfat
	clc
	rts

fat16:
	ldx #0
@copyfat:
	lda fat16_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyfat
	clc
	rts

fat32:
	ldx #0
@copyfat:
	lda fat32_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyfat
	clc
	rts

iso9660:
	ldx #0
@copyiso:
	lda iso_vectors,x
	sta vector_table,x
	inx
	cpx #vectablesize * 2
	bne @copyiso
	clc
	rts
