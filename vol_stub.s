	.export stat_length
	.export stat_type
	.export stat_cluster
	.export vol_fstype
	.export vol_rleflag
	.export vol_secperclus
	.export cluster
	.export romaddr

	.exportzp type_file, type_dir, type_vol, type_lfn, type_other
	.exportzp dirptr, nameptr, clusterptr

; stat_type file types
type_other	= 0
type_file	= 1
type_dir	= 2
type_vol	= 3
type_lfn	= 4

	.segment "BSS"
romaddr:		.res 6
stat_length:		.res 4	; dir entry type
stat_cluster:		.res 4	; dir entry start cluster
vol_fstype:		.res 1	; filesystem type
vol_secperclus:		.res 1	; number of 512-byte sectors per cluster
cluster:		.res 4	; 32-bit cluster address
stat_type:		.res 1	; dir entry type
vol_rleflag:		.res 1	; rle compression flag for isfpgabin

	.segment "ZEROPAGE"
dirptr:		.res 2	; directory pointer
clusterptr:	.res 2	; cluster buffer
nameptr:	.res 2	; name pointer
