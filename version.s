	.export ver_str
	.exportzp ver_major
	.exportzp ver_minor
	.exportzp ver_rev


	.rodata

ver_major	= 0
ver_minor	= 9
ver_rev		= 0

ver_str:
	.byte "0.9", 0
