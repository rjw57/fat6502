	.include "drivecpu.i"

	.export reseth

	.import bootconfig
	.import select_config
	.import fat_read_ptable
	.import boot
	.import dev_init

	.import ctl_select
	.import ctl_select_dev

	.importzp fs_fat32
	.import vol_set_fs

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_puthex
	.import debug_crlf


	.bss

currdev:	.res 1
currctl:	.res 1


	.code

reseth:
	sei
	cld
	ldx #$ff
	txs

	lda #%01100000		; initalize csa reg
	csa_unsafe

	jsr debug_init

	dputs msg_init

	dputs msg_erasefpga
	clf			; erase FPGA

	lda #fs_fat32		; kludge, fixme
	jsr vol_set_fs		; gotta put fs detection in the right place

	lda #0
	sta currctl
@nextctl:
	jsr ctl_select
	bne @devpresent

	jmp @failedctl

@devpresent:
	lda #0
	sta currdev

@tryboot:
	jsr ctl_select_dev
	bcs @next

	lda currdev
	jsr dev_init		; initialize IDE routines
	bcs @next

	lda #<msg_bootingfrom
	ldx #>msg_bootingfrom
	jsr debug_puts
	lda currdev		; secondary master
	jsr debug_puthex
	jsr debug_crlf

	lda #<msg_readptable
	ldx #<msg_readptable
	jsr debug_puts
	jsr fat_read_ptable	; find the boot partition
	bcs @nextfailed

	lda #<msg_selectconfig
	ldx #>msg_selectconfig
	jsr debug_puts
	jsr select_config	; check which config to boot (0-9)
	bcs @nextfailed
	sta bootconfig
	jsr debug_puthex
	jsr debug_crlf

	lda #<msg_boot
	ldx #>msg_boot
	jsr debug_puts
	jsr boot		; load boot code
	bcs @nextfailed

	lda #<msg_done
	ldx #>msg_done
	jsr debug_puts
	jsr debug_done
	lda #%00100000		; reset 65816
	csa_unsafe
	nop
	nop
	nop
	lda #%01110000		; start 65816
	csa_unsafe
	jmp *


@nextfailed:
	lda #<msg_failed
	ldx #>msg_failed
	jsr debug_puts
@next:
	inc currdev
	lda currdev
	cmp #4
	beq @failedctl
	jmp @tryboot

@failedctl:
	inc currctl
	lda currctl
	cmp #2
	beq failure
	jmp @nextctl

failure:
	lda #<msg_allfailed
	ldx #>msg_allfailed
	jsr debug_puts

	inc $d020		; fix me
	jmp *-3


msg_init:
	.byte "C-ONE boot rom initializing",13,10,0
msg_erasefpga:
	.byte "Erasing FPGA",13,10,0
msg_ideinit:
	.byte "Initializing IDE interface",13,10,0
msg_readptable:
	.byte "Reading partition table",13,10,0
msg_selectconfig:
	.byte "Selecting config: ",0
msg_boot:
	.byte "Booting",13,10,0
msg_done:
	.byte "Success, starting 65816",13,10,0
msg_failed:
	.byte "Failure",13,10,0
msg_bootingfrom:
	.byte "Booting from device ",0
msg_allfailed:
	.byte 13,10
	.byte "I, I've been lonely",13,10
	.byte "And I, I've been blind",13,10
	.byte "And I, I've learned nothing",13,10
	.byte "So my hands are firmly tied",13,10
	.byte "To the sinking",13,10
	.byte "  leadweight",13,10
	.byte "  of failure",13,10
	.byte 0

