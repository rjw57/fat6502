	.include "ide.i"
	.include "drivecpu.i"

	.import lba

	.export ide_scan
	.export ide_init
	.export ide_read_sector
	.export ide_read_data
	.export ide_wait_drq
	.export ide_write_data
	.export ide_write_reg
	.export ide_read_reg
	.export ide_read_status
	.export ide_read_error

	.export atapi_init
	.export atapi_read_sector

	.export pagecount
	.export ide_channel
	.export ide_device
	.export ide_sizetab
	.export ide_drivetab
	.export ide_modeltab
	.export offset40
	.exportzp sectorptr

	.exportzp devtype_none
	.exportzp devtype_hd
	.exportzp devtype_cd

	.import debug_puts
	.import debug_puthex
	.import debug_putdigit
	.import debug_put
	.import debug_crlf

	.zeropage

sectorptr:	.res 2	; pointer to where data is loaded


	.bss

ide_channel:		.res 1	; primary ($00) or secondary ($08)
ide_device:		.res 1	; master ($00) or slave ($10)
pagecount:		.res 1	; keeps track of how much data to load
wait_drq_timeout:	.res 1	; timeout counter
wait_ready_timeout:	.res 1
init_timeout:		.res 1
ide_drivetab:		.res 4	; drives that are connected
currdrive:		.res 1	; currently selected drive
currtype:		.res 1	; type of current drive
regmap:			.res 8	; copy of register map
presence:		.res 1	; all regmap bytes or:ed, used to detect drives
identbuf:		.res 512	; buffer for identify info
ide_modeltab:		.res 4*40	; drive model names
ide_sizetab:		.res 4*4	; drive sizes


devtype_none	= $00
devtype_hd	= $01
devtype_cd	= $02


	.rodata

devtab:
	.byte $00	; primary master
	.byte $10	; primary slave
	.byte $08	; secondary master
	.byte $18	; secondary slave

offset40:
	.byte 0
	.byte 40
	.byte 80
	.byte 120


	.code

scanmsg:
	.byte "scanning ide bus",13,10,0

; scan the ide bus
ide_scan:
	lda #<scanmsg
	ldx #>scanmsg
	jsr debug_puts

	ldx #3
@clear:
	lda #devtype_none
	sta ide_drivetab,x
	dex
	bpl @clear

	jmp ide_identify
	ldx #2
	lda #devtype_hd
	sta ide_drivetab,x
	lda #0
	sta ide_sizetab+8
	sta ide_sizetab+9
	sta ide_sizetab+11
	lda #$ff
	sta ide_sizetab+10
	clc
	rts


	lda #0
	sta currdrive

@nextdrive:
	lda currdrive
	jsr debug_putdigit
	jsr debug_crlf
	jsr ide_init

	lda #$e0		; select device
	ora ide_device
	ldy #ide_lba3
	jsr ide_write_reg

	jsr delay_400ns		; delay after selecting


	lda #0			; copy drive regs
	sta presence

	ldy #7
@nextreg:
	tya
	ora ide_channel
	csa
 	ild			; grab A/X

	dputnum
	sta regmap,y
	ora presence		; and all regs for detection
	sta presence

	dey
	bne @nextreg		; skip data reg

	dputcrlf
	cmp #$7f
	beq @done		; nothing to see here

	ldx currdrive		; default to hard disk
	lda #devtype_hd
	sta ide_drivetab,x

	;lda #1
	;cmp regmap+2
	;bne @done
	;cmp regmap+3
	;bne @done
	;lda #$14
	;cmp regmap+4
	;bne @done
	;lda #$eb
	;cmp regmap+5
	;bne @done

	;lda #devtype_cd		; we found an ATAPI drive
	;sta ide_drivetab,x

@done:
	inc currdrive
	lda currdrive
	cmp #4
	bne @nextdrive

	; fall through

	jmp ide_identify
probingmsg:
	.byte "probing device ",0
failedmsg:
	.byte "failed",13,10,0
foundhdmsg:
	.byte "found HD",13,10,0
foundcdmsg:
	.byte "found CD",13,10,0
initedmsg:
	.byte "initialized",13,10,0

; identify the drives on the bus and get their names
ide_identify:
	lda #0
	sta currdrive

@nextdrive:
	lda #<probingmsg
	ldx #>probingmsg
	jsr debug_puts
	lda currdrive
	jsr debug_putdigit
	jsr debug_crlf

;	ldx currdrive
;	lda ide_drivetab,x
;	beq @done
;	sta currtype
;	txa
	lda currdrive
	jsr ide_init
	bcs @failed		; not ready

	lda #<initedmsg
	ldx #>initedmsg
	jsr debug_puts

	;lda #$e0		; select device
	;ora ide_device
	;ldy #ide_lba3
	;jsr ide_write_reg

	;jsr delay_400ns		; delay after selecting

	;jsr ide_wait_ready	; wait for RDY, with timeout
	;bcs @done		; ignore timeout

	lda #idecmd_identify	; identify HD
	ldy #ide_command
	jsr ide_write_reg		; we don't want to get stuck here...

	jsr delay_400ns

	jsr ide_read_error		; check for error condition
	bcc @foundhd

	lda #idecmd_identifypacket	; identify CD
	ldy #ide_command
	jsr ide_write_reg		; we don't want to get stuck here...
	jsr delay_400ns
	jsr ide_read_error		; check for error condition
	bcs @failed			; ok, no CD

	ldx currdrive			; set type to CD
	lda #devtype_cd
	sta ide_drivetab,x

	lda #<foundcdmsg
	ldx #>foundcdmsg
	jmp @readdata

@foundhd:
	ldx currdrive			; set type to HD
	lda #devtype_hd
	sta ide_drivetab,x

	lda #<foundhdmsg
	ldx #>foundhdmsg
@readdata:
	jsr debug_puts

	jsr ide_wait_drq		; wait for data if BSY drops and DRQ
	bcs @failed			; is not set, we're fux0red

	lda #<identbuf
	sta sectorptr
	lda #>identbuf
	sta sectorptr+1

	jsr ide_read_256_words
	bcs @failed

	jsr copymodel
	jsr setdrivesize

@done:
	inc currdrive
	lda currdrive
	cmp #4
	beq @alldone
	jmp @nextdrive
@alldone:
	clc
	rts

@failed:
	lda #<failedmsg
	ldx #>failedmsg
	jsr debug_puts
	ldx currdrive
	lda #devtype_none
	sta ide_drivetab,x
	jmp @done


; copy drive model number
copymodel:
	ldx currdrive
	lda offset40,x
	tax
	ldy #0
@copymodel:
	lda identbuf+55,y	; offset for drive model in identify result
	sta ide_modeltab,x
	jsr debug_put
	lda identbuf+54,y	; offset for drive model in identify result
	sta ide_modeltab+1,x
	jsr debug_put
	inx
	inx
	iny
	iny
	cpy #40
	bne @copymodel
	jsr debug_crlf
	rts


; set drive size
setdrivesize:
	lda currtype
	cmp #devtype_cd
	beq @setcdsize

	lda currdrive		; copy drive size
	asl
	asl
	tax
	lda identbuf + 114	; offset for drive size
	sta ide_sizetab+1,x
	lda identbuf + 115	; flip lo/hi bytes
	sta ide_sizetab,x
	lda identbuf + 116
	sta ide_sizetab+3,x
	lda identbuf + 117
	sta ide_sizetab+2,x
	rts

@setcdsize:
	lda currdrive		; set drive size
	asl
	asl
	tax
:	lda #0
	sta ide_sizetab,x
	iny
	inx
	cpx #4
	bne :-
	rts


; initialize device. call with dev 0..3 in A
atapi_init:
ide_init:
	tax
	lda devtab,x
	pha
	and #$0f
	sta ide_channel
	pla
	and #$f0
	sta ide_device
	ora #$e0
	ldy #ide_lba3
	jsr ide_write_reg

	jsr delay_400ns

	lda #0
	sta init_timeout

:	jsr ide_wait_ready	; wait for ready status, with timeout
	bcc @done

	jsr delay_400ns
	inc init_timeout
	bne :-

	lda #<timeoutmsg
	ldx #>timeoutmsg
	jsr debug_puts
	jsr ide_read_status
	jsr debug_puthex
	jsr debug_crlf
	sec
@done:
	rts

	.rodata
timeoutmsg:
	.byte "timeout waiting for RDY, status = ",0
	.code


; read 512-byte sector to sectorptr
ide_read_sector:
	ldy #ide_lba3
	lda #$e0		; lba addressing
	ora ide_device
	ora lba+3
	jsr ide_write_reg

	jsr delay_400ns		; delay after selecting device

	ldy #ide_lba2
	lda lba+2
	jsr ide_write_reg

	ldy #ide_lba1
	lda lba+1
	jsr ide_write_reg

	ldy #ide_lba0
	lda lba
	jsr ide_write_reg

	ldy #ide_scount		; read a single sector
	lda #1
	jsr ide_write_reg

	ldy #ide_command	; send ide read command
	lda #idecmd_read_sector
	jsr ide_write_reg

	jsr delay_400ns		; delay after sending command

	jsr ide_read_error
	bcc ide_read_256_words
	rts


ide_read_256_words:
	jsr ide_wait_drq	; wait for DRQ
	bcs @timeout

	lda #>512		; number of pages to load
	sta pagecount

	ldy #0			; store data at sectorptr

@nextpage:
	jsr ide_read_data
	sta (sectorptr),y
	iny
	txa
	sta (sectorptr),y
	iny
	bne @nextpage

	inc sectorptr+1

	dec pagecount
	bne @nextpage

	clc
	rts

@timeout:
	sec
	rts


; wait for DRQ, with timeout
ide_wait_drq:
	lda #ide_status
	ora ide_channel
	csa
	lda #0
	sta wait_drq_timeout
@checkstatus:
	ild
	and #$88		; check for BSY not set
	bmi @checkstatus
	and #$08		; check that DRQ is set
	bne @ready

	inc wait_drq_timeout
	bne @checkstatus

	sec
	rts

@ready:	clc
	rts


; wait for RDY
ide_wait_ready:
	lda #0
	sta wait_ready_timeout

	lda #ide_status
	ora ide_channel
	csa
@checkstatus:
	ild
	and #$c0
	bmi @checkstatus
	and #$40
	bne @done

	inc wait_ready_timeout
	bne @checkstatus

	sec
	rts

@done:	clc
	rts


; read A/X from ide data register
ide_read_data:
	lda #ide_status
	ora ide_channel
	csa
@checkstatus:
	ild
	and #$08		; check that DRQ is set
	beq @checkstatus
	lda ide_channel
	csa
	ild
	cmp #$00
	rts


; write A/X to ide data register
ide_write_data:
	pha
	txa
	pha
	lda #ide_status
	ora ide_channel
	csa
@checkstatus:
	ild
	and #$08		; check that DRQ is set
	beq @checkstatus
	lda ide_channel
	csa
	pla
	tax
	pla
	ist
	rts


; write A/X to register in Y
ide_write_reg:
	pha
	lda #ide_status		; read ide status
	ora ide_channel
	csa
	cpy #7
	beq @write_command
@checkstatus:	
	ild
	and #$80		; check that BSY isn't set
	bne @checkstatus
@do_write:
	tya			; write to register in Y
	ora ide_channel
	csa
	pla
	ist			; write A/X
	rts

@write_command:	
	ild
	eor #$40		; check that RDY is set and
	and #$c0		; that BSY isn't set
	bne @write_command
	jmp @do_write


; read A/X from register in Y
ide_read_reg:
	lda #ide_status		; read ide status
	ora ide_channel
	csa
@checkstatus:	
	ild
	and #$80		; check that BSY isn't set
	bne @checkstatus
	tya			; read from register in Y
	ora ide_channel
	csa
 	ild			; grab A/X
	rts


; read the IDE status register
ide_read_status:
	lda #ide_status		; read ide status
	ora ide_channel
	csa
	ild
	cmp #$00
	rts


; read the error register, return error status in carry
ide_read_error:
	lda #ide_status
	ora ide_channel
	csa
@read:	
	ild
	and #$81
	bmi @read
	lsr
	lda #ide_error
	ora ide_channel
	csa
	ild
	rts


; read sector from ATAPI device to sectorptr
atapi_read_sector:
	ldy #ide_lba3
	lda #$e0		; lba addressing
	ora ide_device
	;ora lba+3
	jsr ide_write_reg

	jsr delay_400ns		; delay after selecting device

	ldy #ide_lba1		; 12 byte command
	lda #12
	jsr ide_write_reg
	ldy #ide_lba2
	lda #0
	jsr ide_write_reg

	ldy #ide_command	; send ide packet command
	lda #idecmd_packet
	jsr ide_write_reg

	jsr delay_400ns		; delay after sending command

	lda #atapicmd_read	; read command
	ldx #0
	jsr ide_write_data

	lda lba+3		; block address
	ldx lba+2
	jsr ide_write_data
	lda lba+1
	ldx lba
	jsr ide_write_data

	lda #0
	ldx #0			; length msb
	jsr ide_write_data
	lda #1			; length lsb
	ldx #0
	jsr ide_write_data
	lda #0
	ldx #0
	jsr ide_write_data

	jsr delay_400ns		; delay after sending command

	jsr ide_read_error
	bcc @ok
	rts

@ok:
	lda #>2048		; number of pages to load
	sta pagecount

	ldy #0			; store data at sectorptr

@nextpage:
	jsr ide_read_data
	sta (sectorptr),y
	iny
	txa
	sta (sectorptr),y
	iny
	bne @nextpage

	inc sectorptr+1

	dec pagecount
	bne @nextpage

	clc
	rts


; 400 ns delay
delay_400ns:
	.ifdef DEBUG
	rts
	.endif

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
