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

	.import stat_cluster
	.import stat_length
	.import lba


fs_iso9660	= $96


	.code

iso_read_ptable:
iso_cdboot:
iso_cdroot:
iso_dir_first:
iso_dir_next:
iso_next_clust:
iso_read_clust:
iso_endofdir:
iso_isfpgabin:
iso_isrom:
iso_stat:
iso_firstnamechar:
	sec
	rts
