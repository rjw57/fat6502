	.include "ide.i"
	.include "drivecpu.i"

	.import ide_init
	.import ide_read_sector
	.import ide_read_data
	.import ide_write_data
	.import ide_write_reg
	.import ide_read_reg
	.import ide_read_status
	.import ide_read_error
	.import lba

	.import sectorbuf


atapicmd_read	= $28		; read sector


	.bss



	.code


atapi_sendcmd:
	ldx #ide_lba3
	lda #$e0		; lba addressing
	ora ide_device
	ora lba+3
	jsr ide_write_reg

	jsr delay_400ns		; delay after selecting device

	ldx #ide_lba1		; 12 byte command
	lda #12
	jsr ide_write_reg
	ldx #ide_lba2
	lda #0
	jsr ide_write_reg

	ldx #ide_command	; send ide packet command
	lda #idecmd_packet
	jsr ide_write_reg

	jsr delay_400ns		; delay after sending command

	lda #atapicmd_read	; send read command
	jsr ide_write_data

	lda #0
	jsr ide_write_data

	lda lba+3		; send block address
	jsr ide_write_data
	lda lba+2
	jsr ide_write_data
	lda lba+1
	jsr ide_write_data
	lda lba
	jsr ide_write_data

	lda #0
	jsr ide_write_data

	lda #0			; transfer length
	jsr ide_write_data
	lda #1
	jsr ide_write_data

	lda #0
	jsr ide_write_data
	lda #0
	jsr ide_write_data
	lda #0
	jsr ide_write_data
