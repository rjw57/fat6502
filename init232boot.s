	.include "drivecpu.i"


	.export init232boot

	.exportzp src, dest

	.import	rs232boot

	.import timestamp

	.import __RELOC_SIZE__
	.import __RELOC_RUN__
	.import __RELOC_LOAD__

	.import debug_init
	.import debug_puts
	.import debug_puthex


	.zeropage

src:	.res 2
dest:	.res 2


	.code

init232boot:
	jsr debug_init

	ldax __RELOC_LOAD__
	stax src

	ldax __RELOC_RUN__
	stax dest

	ldy #0
	ldx #>__RELOC_SIZE__
	beq @donehi

:	lda (src),y
	sta (dest),y
	iny
	bne :-
	inc src+1
	inc dest+1
	dex
	bne :-
@donehi:

	ldx #<__RELOC_SIZE__
	beq @donelo

:	lda (src),y
	sta (dest),y
	iny
	dex
	bne :-
@donelo:

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
