	.include "drivecpu.i"

	.exportzp fs_iso9660

	.export iso_read_ptable
	.export iso_cd
	.export iso_cdroot
	.export iso_dir_first
	.export iso_dir_next
	.export iso_next_clust
	.export iso_read_clust


fs_iso9660	= $96


	.code

iso_read_ptable:
iso_cd:
iso_cdroot:
iso_dir_first:
iso_dir_next:
iso_next_clust:
iso_read_clust:
	sec
	rts
