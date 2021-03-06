	.include "drivecpu.i"

	.export reseth
	.export warmstart
	.export devicon

	.import bootconfig
	.import select_config
	.import boot
	.import drawbooticon
	.import printvolname
	.import entermenu
	.import dev_init
	.import dev_find_volume
	.import devtype
	.import devmap
	.importzp ptr
	.import __BSS_RUN__
	.import __BSS_SIZE__

	.import ctl_select
	.import ctl_select_dev

	.import vol_fstype
	.import vol_set_fs
	.import vol_read_volid

	.import ver_str
	.import ver_major
	.import ver_minor
	.import ver_rev

	.import gfx_drawlogo
	.import gfx_cls
	.import gfx_gotoxy
	.import gfx_putchar
	.import gfx_puts
	.import gfx_drawicon

	.import debug_init
	.import debug_done
	.import debug_put
	.import debug_puts
	.import debug_putdigit
	.import debug_crlf

	.import checkaltrom

	;.import init232boot


	.bss

currdev:	.res 1
currctl:	.res 1


;	.segment "RELOC"

; this is a dummy segment just to suppress an ld65 warning


	.code

reseth:
	sta bootconfig
	sei
	cld
	ldx #$ff
	txs

	ldx #0			; clear zp and stack
	txa
:	sta $00,x
	sta $0100,x
	inx
	bne :-

warmstart:
	lda bootconfig		; save bootconfig, ugly ugly
	pha
	jsr clrbss		; clear BSS segment
	pla
	sta bootconfig

	jsr gfx_cls		; clear graphics screen
	jsr gfx_drawlogo	; print C-ONE logo
	ldy #3
	ldx #66
	jsr gfx_gotoxy
	ldax #msg_bootromv
	jsr gfx_puts
	ldax #ver_str
	jsr gfx_puts

	lda #0			; flag whether we should display boot menu
	sta entermenu

	;jsr select_config	; check which config to boot (0-9)
	lda bootconfig
	sta bootconfig
	dec entermenu		; force boot menu
	jmp @debuginit
	bcs @default		; is holding a config key?

	;cmp #'S'
	;bne @checkflash
	;jmp init232boot	; download rom

@checkflash:
	cmp #'F'
	bne @debuginit

;	lda #%00000111		; keep /DMA high or we can't flash later
;	ctl
	jsr debug_done		; disable rs-232
	jmp @configdone

@default:
	dec entermenu		; enter menu later
	jmp @debuginit

@debuginit:
	lda #%00000110		; pull /DMA low or rs-232 won't work
	ctl
	jsr debug_init		; initialize rs-232
@configdone:


	ldx #28			; print searching for boot device
	ldy #12
	jsr gfx_gotoxy
	ldax #msg_searching
	jsr gfx_puts

	ldx #38			; draw icon
	ldy #14
	jsr gfx_gotoxy
	ldax #devicon_none
	jsr gfx_drawicon


	ldax #msg_init1		; print version number
	jsr debug_puts
	ldax #ver_str
	jsr debug_puts
	ldax #msg_init2
	jsr debug_puts
	ldax #msg_init3
	jsr debug_puts

	ldax #msg_erasefpga
	jsr debug_puts
;tobix was here
;	lda #%00000101		; erase FPGA
;	ctl
;	lda #%00000111		; back to normal
;	ctl

	lda #0			; start with controller 0
	sta currctl
@nextctl:
	jsr ctl_select		; select
	bne @devpresent		; returns number of connected devices

	jmp @failedctl

@devpresent:
	lda #0
	sta currdev

	ldy currctl		; populate device array
	ldx #72
	jsr gfx_gotoxy
	ldx currdev		; print small icon
:	lda devmap,x
	asl
	tax
	lda devchar,x
	jsr gfx_putchar
	inx
	lda devchar,x
	jsr gfx_putchar
	inc currdev
	ldx currdev
	cpx #4
	bne :-

	lda #0			; start with dev 0
	sta currdev

@tryboot:
	jsr ctl_select_dev	; select
	bcc @selected
	jmp @next
@selected:
	jsr drawbooticon	; draw icon

	lda currdev
	jsr dev_init		; initialize low level routines
	bcs @next

	ldax #msg_bootingfrom	; print device number that we're booting from
	jsr debug_puts
	lda currdev
	jsr debug_putdigit
	jsr debug_crlf

	jsr dev_find_volume	; inspect filesystem
	bcs @next
	jsr vol_set_fs		; set the filesystem
	jsr vol_read_volid	; initialize volume data
	bcs @next

	jsr printvolname	; print volume name

	ldax #msg_selectconfig	; print config number
	jsr debug_puts
	lda bootconfig
	jsr debug_put
	jsr debug_crlf

	ldax #msg_boot
	jsr debug_puts
	jsr boot		; load boot code
	bcs @nextfailed

	ldax #msg_done
	jsr debug_puts
	jsr debug_done
	jsr gfx_cls		; clear screen
;	lda #%00000010		; reset main CPU
;	ctl
;	nop
;	nop
;	nop
;	lda #%00000110		; start main CPU
;	ctl
	rti
;	jmp *			; success


@nextfailed:
	ldax #msg_failed		; soft failure
	jsr debug_puts
@next:
	inc currdev
	lda currdev
	cmp #4
	beq @failedctl
	jmp @tryboot

@failedctl:
	inc currctl		; all devs on controller failed
	lda currctl
	cmp #3
	beq failure
	jmp @nextctl

failure:
	ldax #msg_allfailed	; now we're screwed
	jsr debug_puts
	jsr gfx_cls		; clear screen
	rti
;	jmp *			; failure


; clear BSS segment aka initialize variable space
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


	.rodata

devicon_none:	.incbin "devtype_none.bin"
devicon_hd:	.incbin "devtype_hd.bin"
devicon_cd:	.incbin "devtype_cd.bin"
devicon_floppy:	.incbin "devtype_floppy.bin"
devicon_rom:	.incbin "devtype_rom.bin"

devicon:
	.word devicon_none
	.word devicon_hd
	.word devicon_cd
	.word devicon_floppy
	.word devicon_rom

devchar:
	.byte 0, 0
	.byte $8d, $8e
	.byte $8f, $90
	.byte $91, $92
	.byte $93, $94

msg_init1:
	.byte "C-ONE boot rom v",0
msg_init2:
	.byte " (",0
msg_init3:
	.byte ") initializing",13,10,0
msg_erasefpga:
	.byte "Erasing FPGA",13,10,0
msg_ideinit:
	.byte "Initializing IDE interface",13,10,0
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

msg_bootromv:
	.byte "Boot ROM v",0
msg_searching:
	.byte "Searching for boot device",0
