	.macpack longbranch
	.include "drivecpu.i"
	.include "ide.i"

	.export reseth
	
	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_put
	.import debug_puthex

	.import ide_wait_drq
	.import ide_read_data
	.import ide_read_error
	.import ide_write_reg
	.import ide_write_reg_no_wait
	.import atapi_read_sector

	.import lba
	.importzp sectorptr
	.import ide_channel
	.import ide_device


drvtype_none	= $00
drvtype_hd	= $01
drvtype_cd	= $02


	.bss

drv:		.res 1
presence:	.res 1
regmap:		.res 8
drvtype:	.res 4
linecount:	.res 1
linebuf:	.res 16
errcount:	.res 1
rdtimeout:	.res 1
clusterbuf:	.res 2048


	.code

reseth:
	jsr debug_init

	lda #<initmsg
	ldx #>initmsg
	jsr debug_puts

	jsr delay_400ns		; let the drives come to life

	lda #0
	sta drv

@nextdrv:
	ldx drv			; select channel
	lda drvtab,x
	and #$0f
	php
	sta ide_channel
	ora #ide_lba3
	csa

	lda #<primarymsg
	ldx #>primarymsg
	plp
	beq @notsecondary
	lda #<secondarymsg
	ldx #>secondarymsg
@notsecondary:
	jsr debug_puts

	ldx drv			; select device
	lda drvtab,x
	and #$f0
	php
	sta ide_device
	ora #$e0
	ist

	lda #<mastermsg
	ldx #>mastermsg
	plp
	beq @notslave
	lda #<slavemsg
	ldx #>slavemsg
@notslave:
	jsr debug_puts

	jsr delay_400ns		; delay after writing	


	jsr copyregs
	lda presence
	cmp #$7f
	beq @nodrv

	jsr checkforcd
	beq @cd

	ldy drv
	lda #drvtype_hd
	sta drvtype,y

	lda #<hdmsg
	ldx #>hdmsg
	jmp @print

@cd:
	ldy drv
	lda #drvtype_cd
	sta drvtype,y

	lda #<cdmsg
	ldx #>cdmsg
	jmp @print

@nodrv:
	ldy drv
	lda #drvtype_none
	sta drvtype,y

	lda #<nodrvmsg
	ldx #>nodrvmsg
@print:
	jsr debug_puts

@next:
	inc drv
	lda drv
	cmp #4
	jne @nextdrv



identify:
	ldy #0
	sty drv

@nextdrv:
	lda drvtype,y
	jeq @next

	lda #0
	sta errcount

	lda #<identifymsg
	ldx #>identifymsg
	jsr debug_puts
	lda drv
	jsr debug_puthex
	lda #<crlf
	ldx #>crlf
	jsr debug_puts

@tryagain:
	ldy drv
	lda drvtab,y		; select channel
	and #$0f
	sta ide_channel
	ora #ide_status
	csa
@waitbsy:
	ild			; wait for BSY to drop
	lsr			; ERR -> C
	bcc @checkbsy

	inc errcount
	lda errcount
	cmp #4
	bne @again

	lda #<failmsg
	ldx #>failmsg
	jsr debug_puts
	jmp @next

@again:
	lda #<tryagainmsg
	ldx #>tryagainmsg
	jsr debug_puts
	jmp @tryagain

@checkbsy:
	and #$40		; mask BSY>>1
	bne @waitbsy

	lda ide_channel		; select device
	ora #ide_lba3
	csa

	lda drvtab,y
	and #$f0
	sta ide_device
	ora #$e0
	ist

	jsr delay_400ns

	ldx #idecmd_identify

	lda drvtype,y
	cmp #drvtype_cd
	bne @notcd

	ldx #idecmd_identifypacket
@notcd:
	txa
	ldy #ide_command
	jsr ide_write_reg_no_wait

	jsr delay_400ns

	jsr ide_read_error
	bcc @noerror

	pha
	lda #<errormsg
	ldx #>errormsg
	jsr debug_puts
	pla
	jsr debug_puthex
	lda #<crlf
	ldx #>crlf
	jsr debug_puts
	jmp @next


@noerror:
	lda #<readingmsg
	ldx #>readingmsg
	jsr debug_puts

	lda #0
	sta rdtimeout
@timeout:
	jsr ide_wait_drq

	bcc @dataready
	inc rdtimeout
	bne @timeout

	lda #<timeoutmsg
	ldx #>timeoutmsg
	jsr debug_puts
	jmp @next
@dataready:


	lda #32
	sta linecount

@nextline:
	ldy #0
@nextword:
	jsr ide_read_data
	pha
	txa
	sta linebuf,y
	jsr debug_puthex
	iny

	pla
	sta linebuf,y
	jsr debug_puthex
	iny

	lda #' '
	jsr debug_put

	cpy #16
	bne @nextword

	lda #' '
	jsr debug_put

	ldy #0
@printnext:
	lda linebuf,y
	tax

	cmp #$20
	bcs @notlow
	ldx #'.'
@notlow:
	cmp #$7f
	bcc @nothigh
	ldx #'.'
@nothigh:
	txa
	jsr debug_put

	iny
	cpy #16
	bne @printnext

	lda #<crlf
	ldx #>crlf
	jsr debug_puts

	dec linecount
	bne @nextline


@next:
	ldy drv
	lda drvtype,y
	cmp #drvtype_cd
	bne @skipatapitest

	; atapi test

	lda #<atapimsg
	ldx #>atapimsg
	jsr debug_puts

	ldx #3
	lda drvtab,x
	and #$0f
	sta ide_channel
	lda drvtab,x
	and #$f0
	sta ide_device

	lda #<clusterbuf
	ldx #>clusterbuf
	sta sectorptr
	stx sectorptr+1

	lda #16
	sta lba
	lda #0
	sta lba+1
	sta lba+2
	sta lba+3

	jsr atapi_read_sector
	bcs @skipatapitest

	ldx #0
@nexthex:
	lda clusterbuf,x
	jsr debug_puthex
	inx
	cpx #16
	bne @nexthex
	lda #<crlf
	ldx #>crlf
	jsr debug_puts

@skipatapitest:
	inc drv
	ldy drv
	cpy #4
	jne @nextdrv

	lda #<alldonemsg
	ldx #>alldonemsg
	jsr debug_puts

	lda #$30
	csa_unsafe
	jmp *


; copy current drive's registers
copyregs:
	lda #0
	sta presence

	ldy #1			; skip data reg

@nextreg:
	tya
	ora ide_channel
	csa
 	ild			; grab A/X

	sta regmap,y
	ora presence		; and all regs for detection
	sta presence

	iny
	cpy #8
	bne @nextreg

	rts


; check if register signature looks like ATAPI
checkforcd:
	lda #1
	cmp regmap+2
	bne @done
	cmp regmap+3
	bne @done
	lda #$14
	cmp regmap+4
	bne @done
	lda #$eb
	cmp regmap+5
@done:
	rts


; 400 ns delay
delay_400ns:
	ldx #10 * cpuspeed
:	dex
	nop
	bit $ea
	nop
	bit $ea
	nop
	bit $ea
	nop
	bit $ea
	nop
	bit $ea
	nop
	bit $ea
	nop
	bit $ea
	bne :-			; 40*x - 1
	rts


	.rodata

initmsg:
	.byte "IDE bus register scan",13,10,0
primarymsg:
	.byte "pri ",0
secondarymsg:
	.byte "sec ",0
mastermsg:
	.byte "dev 0  ",0
slavemsg:
	.byte "dev 1  ",0
donemsg:
	.byte "Done."
crlf:
	.byte 13,10,0
nodrvmsg:
	.byte "(none)",13,10,0
hdmsg:
	.byte "Hard drive",13,10,0
cdmsg:
	.byte "CD-ROM",13,10,0
identifymsg:
	.byte "Identify Device ",0
errormsg:
	.byte "Failed, errno ",0
failmsg:
	.byte "Failed, skipping device",13,10,0
tryagainmsg:
	.byte "Error, trying again",13,10,0
readingmsg:
	.byte "Command sent, reading data",13,10,0
timeoutmsg:
	.byte "***TIMEOUT***",13,10,0
atapimsg:
	.byte "ATAPI test",13,10,0
alldonemsg:
	.byte "All done, this is when I'd normally try to boot",13,10,0


drvtab:
	.byte $00	; primary master
	.byte $10	; primary slave
	.byte $08	; secondary master
	.byte $18	; secondary slave

