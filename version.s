	.export ver_str
	.export ver_major
	.export ver_minor
	.export ver_rev


	.segment "VERSION"

ver_major:	.byte 0
ver_minor:	.byte 9
ver_rev:	.byte 2

ver_str:
	.byte "0.9.2", 0
