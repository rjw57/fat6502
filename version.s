	.export ver_str
	.export ver_major
	.export ver_minor
	.export ver_rev


	.segment "VERSION"

ver_major:	.byte 1
ver_minor:	.byte 2
ver_rev:	.byte 0

ver_str:
	.byte "1.2a", 0
