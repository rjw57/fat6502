	.include "drivecpu.i"


	.export init232boot
	.import relocate

	.import	rs232boot

	.import timestamp

	.import debug_init
	.import debug_puts
	.import debug_puthex


	.code

init232boot:
	jsr debug_init

	ldax initmsg1
	jsr debug_puts
	ldax timestamp
	jsr debug_puts
	ldax initmsg2
	jsr debug_puts

	jmp rs232boot


	.rodata

initmsg1:
	.byte "RS-232 boot rom downloader (",0
initmsg2:
	.byte ")",13,10,0
