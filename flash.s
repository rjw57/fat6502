	.include "drivecpu.i"

	.export flash_addr_clear
	.export flash_addr_inc
	.export flash_addr_shift
	.export flash_data_read
	.export flash_reg_tab
	.exportzp flash_reg


	.zeropage

flash_reg:	.res 1


	.code

flash_addr_clear:
	ldx #dev_clk2
	lda #flash_clear
	sca
	ldx #dev_release
	sca
	rts

flash_addr_inc:
	ldx #dev_clk2
	lda #flash_inc
	sca
	ldx #dev_release
	sca
	rts

flash_addr_shift:
	ldx #dev_clk2
	lda #flash_shift
	sca
	ldx #dev_release
	sca
	rts

flash_data_read:
	ldx #dev_clk2
	lda flash_reg
	sca
	ild
	ldx #dev_release
	sca
	rts


	.rodata

flash_reg_tab:
	.byte <flash_data
	.byte <flash_data + 1
	.byte <flash_data + 2
	.byte <flash_data + 3
