	.include "drivecpu.i"

	.export reseth

	.import bootconfig
	.import select_config
	.import boot
	.import dev_init
	.importzp ptr
	.import __BSS_RUN__
	.import __BSS_SIZE__

	.import ctl_select
	.import ctl_select_dev

	.import vol_fstype
	.import vol_set_fs
	.import vol_read_ptable

	.import timestamp

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_putdigit
	.import debug_crlf


	.bss

currdev:	.res 1
currctl:	.res 1


	.segment "RELOC"

; this is a dummy segment just to suppress an ld65 warning


	.code

reseth:
	sei
	cld
	ldx #$ff
	txs

	lda #%01100000		; initalize csa reg
	csa_unsafe

	ldx #0			; clear zp and stack
	txa
:	sta $00,x
	sta $0100,x
	inx
	bne :-

	jsr clrbss		; clear BSS segment

	lda #$ff
	sta bootconfig

	jsr debug_init

	ldax msg_init1
	jsr debug_puts
	ldax timestamp
	jsr debug_puts
	ldax msg_init2
	jsr debug_puts

	ldax msg_erasefpga
	jsr debug_puts
	clf			; erase FPGA

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

	ldax msg_bootingfrom
	jsr debug_puts
	lda currdev
	jsr debug_putdigit
	jsr debug_crlf

	ldax msg_readptable
	jsr debug_puts
	lda vol_fstype
	pha
	jsr vol_read_ptable	; find the boot partition
	pla
	bcs @nextfailed

	cmp vol_fstype
	beq @fsdidntchange

	lda vol_fstype
	jsr vol_set_fs
@fsdidntchange:

	bit bootconfig		; no need to grab it twice
	bpl @wehaveaconfig
	ldax msg_selectconfig
	jsr debug_puts
	jsr select_config	; check which config to boot (0-9)
	bcs @nextfailed
	sta bootconfig
	jsr debug_putdigit
	jsr debug_crlf
@wehaveaconfig:

	ldax msg_boot
	jsr debug_puts
	jsr boot		; load boot code
	bcs @nextfailed

	ldax msg_done
	jsr debug_puts
	jsr debug_done
	lda #%00100000		; reset 65816
	csa_unsafe
	nop
	nop
	nop
	lda #%01110000		; start 65816
	csa_unsafe
	trc $ff			; success
	jmp *


@nextfailed:
	ldax msg_failed
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
	ldax msg_allfailed
	jsr debug_puts

	inc $d020		; fix me
	jmp *-3


; clear BSS segment
clrbss:
	lda #<__BSS_RUN__
	sta ptr
	lda #>__BSS_RUN__
	sta ptr+1

	ldy #0

	ldx #>__BSS_SIZE__
	beq @donehi

@clrhi:
	lda #0
:	sta (ptr),y
	iny
	bne :-
	inc ptr+1
	dex
	bne @clrhi
@donehi:
	ldx #<__BSS_SIZE__
	beq @donelo

	lda #0
:	sta (ptr),y
	iny
	dex
	bne :-
@donelo:
	rts


msg_init1:
	.byte "C-ONE boot rom (",0
msg_init2:
	.byte ") initializing",13,10,0
msg_erasefpga:
	.byte "Erasing FPGA",13,10,0
msg_ideinit:
	.byte "Initializing IDE interface",13,10,0
msg_readptable:
	.byte "Reading partition table",13,10,0
msg_selectconfig:
	.byte "Selecting config ",0
msg_boot:
	.byte "Booting",13,10,0
msg_done:
	.byte "Success, starting main CPU",13,10,0
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

