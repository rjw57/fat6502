; this file acts as an abstraction layer between the file system
; specific routines and the boot code


	.include "drivecpu.i"

	.export vol_set_fs
	.export vol_read_volid
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
	.export vol_isdesc
	.export vol_volname
	.export vol_write_clust

	.export romaddr
	.export stat_length
	.export stat_cluster
	.export stat_type
	.export vol_fstype
	.export vol_secperclus
	.export cluster
	.exportzp dirptr, nameptr, clusterptr

	.exportzp type_file, type_dir, type_vol, type_lfn, type_other

	.importzp fs_fat12		; fat12/16/32 support
	.importzp fs_fat16
	.importzp fs_fat32

	.import fat_read_volid
	.import fat_cdboot
	.import fat_cdroot
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
	.import fat_isdesc
	.import fat_volname
	.import fat_write_clust

	.importzp fs_iso9660		; iso9660 support

	.import iso_read_volid
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
	.import iso_isdesc
	.import iso_volname
	.import iso_write_clust


; stat_type file types
type_other	= 0
type_file	= 1
type_dir	= 2
type_vol	= 3
type_lfn	= 4


	.segment "VOLZP" : zeropage

dirptr:		.res 2	; directory pointer
clusterptr:	.res 2	; cluster buffer


	.zeropage

nameptr:	.res 2	; name pointer


	.bss

	.align 2
vectablesize		= 17
vector_table:		.res vectablesize * 2
vol_read_volid_vector	= vector_table
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
vol_isdesc_vector	= vector_table + 28
vol_fat_volname_vector	= vector_table + 30
vol_write_clust_vector	= vector_table + 32


	.segment "VOLVECTORS"

vol_set_fs:		jmp _vol_set_fs
vol_read_volid:		jmp (vol_read_volid_vector)
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
vol_isdesc:		jmp (vol_isdesc_vector)
vol_volname:		jmp (vol_fat_volname_vector)
vol_write_clust:	jmp (vol_write_clust_vector)

			.res 10


	.segment "VOLBSS"

romaddr:		.res 6
stat_length:		.res 4	; dir entry type
stat_cluster:		.res 4	; dir entry start cluster
vol_fstype:		.res 1	; filesystem type
vol_secperclus:		.res 1	; number of 512-byte sectors per cluster
cluster:		.res 4	; 32-bit cluster address
stat_type:		.res 1	; dir entry type


	.rodata

fat12_vectors:
	.word fat_read_volid
	.word fat_cdboot
	.word fat_cdroot
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
	.word fat_isdesc
	.word fat_volname
	.word fat_write_clust

fat16_vectors:
	.word fat_read_volid
	.word fat_cdboot
	.word fat_cdroot
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
	.word fat_isdesc
	.word fat_volname
	.word fat_write_clust

fat32_vectors:
	.word fat_read_volid
	.word fat_cdboot
	.word fat_cdroot
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
	.word fat_isdesc
	.word fat_volname
	.word fat_write_clust

iso_vectors:
	.word iso_read_volid
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
	.word iso_isdesc
	.word iso_volname
	.word iso_write_clust


	.code


; call with filesystem identifier in A
_vol_set_fs:
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
