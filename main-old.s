	.include "drivecpu.i"

	.export reseth

	.import bootconfig
	.import select_config
	.import fat_read_ptable
	.import ide_boot
	.import ide_init

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_puthex
	.import dstr_init
	.import dstr_erasefpga
	.import dstr_ideinit
	.import dstr_readptable
	.import dstr_selectconfig
	.import dstr_crlf
	.import dstr_boot
	.import dstr_done
	.import dstr_failed


	.code

reseth:
	sei
	cld
	ldx #$ff
	txs

	lda #%01100000		; initalize csa reg
	csa_unsafe

	jsr debug_init

	dputs dstr_init

	dputs dstr_erasefpga
	clf			; erase FPGA

	dputs dstr_ideinit
	lda #2			; secondary master
	jsr ide_init		; initialize IDE routines
	bcs boot_fail

	dputs dstr_readptable
	jsr fat_read_ptable	; find the boot partition
	bcs boot_fail

	dputs dstr_selectconfig
	jsr select_config	; check which config to boot (0-9)
	bcs boot_fail
	sta bootconfig
	dputnum
	dputs dstr_crlf

	dputs dstr_boot
	jsr ide_boot		; load boot code
	bcs boot_fail

	dputs dstr_done
	jsr debug_done
	lda #%00100000		; reset 65816
	csa_unsafe
	nop
	nop
	nop
	lda #%01110000		; start 65816
	csa_unsafe
	jmp *


boot_fail:
	dputs dstr_failed
	inc $d020		; fix me
	jmp *-3
