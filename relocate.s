	.include "drivecpu.i"

	.export relocate
	.exportzp src, dest

	.import __RELOC_SIZE__
	.import __RELOC_RUN__
	.import __RELOC_LOAD__


	.zeropage

src:	.res 2
dest:	.res 2


	.code

relocate:
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
