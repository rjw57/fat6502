	.include "drivecpu.i"

	.export reseth
	.export warmstart

	.importzp ptr

	.import vol_cdboot
	.import vol_cdroot
	.import vol_dir_first
	.import vol_dir_next
	.import vol_next_clust
	.import vol_read_clust
	.import vol_stat
	.import vol_isrom
	.import vol_isfpgabin
	.import vol_isdrivebin
	.import vol_isflashbin
	.import vol_firstnamechar
	.import vol_endofdir
	.import vol_volname
	.import vol_fstype
	.import vol_set_fs
	.import vol_read_volid

	.import ctl_select
	.import ctl_select_dev

	.import dev_init
	.import dev_find_volume

	.import stat_length
	.import stat_cluster

	.import debug_init
	.import debug_done
	.import debug_puts
	.import debug_put
	.import debug_putdigit
	.import debug_puthex
	.import debug_crlf


	.zeropage

nameptr:	.res 2

	.bss

currdev:	.res 1
currctl:	.res 1
namelen:	.res 1


	.code

warmstart:
reseth:
	sei
	ldx #$ff
	txs

	jsr debug_init

	ldax #msg_hello
	jsr debug_puts


	lda #0			; start with controller 0
	sta currctl
@nextctl:
	jsr ctl_select		; select
	bne @devpresent		; returns number of connected devices

	jmp @failedctl

@devpresent:
	lda #0
	sta currdev

@tryboot:
	jsr ctl_select_dev	; select
	bcc @selected
	jmp @next
@selected:
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

	;jsr vol_volname		; print volume name
	;jsr debug_puts

	jsr listdir		; list directory

@next:
	inc currdev
	lda currdev
	cmp #4
	beq @failedctl
	jmp @tryboot

@failedctl:
	inc currctl		; all devs on controller failed
	lda currctl
	cmp #2
	beq failure
	jmp @nextctl

failure:
	ldax #msg_allfailed	; now we're screwed
	jsr debug_puts
	rti


listdir:
	jsr vol_cdroot
	jsr vol_dir_first	; find the first dir entry
@checkentry:
	jsr vol_endofdir	; check for end of dir
	beq @lastentry

	jsr vol_stat		; get name, cluster, len
	stax nameptr
	sty namelen

	ldy #0			; print
:	lda (nameptr),y
	jsr debug_put
	iny
	cpy namelen
	bne :-

	lda #20			; print 20 - len spaces
	sec
	sbc namelen
	tax
	lda #' '
:	jsr debug_put
	dex
	bne :-

	ldx #3			; print length
:	lda stat_length,x
	jsr debug_puthex
	dex
	bne :-

	lda #' '		; spaces
	jsr debug_put
	jsr debug_put

	ldx #3			; print cluster
:	lda stat_cluster,x
	jsr debug_puthex
	dex
	bne :-

	jsr debug_crlf		; newline

@next:
	jsr vol_dir_next	; find the next dir entry
	bcc @checkentry		; premature end of dir

@lastentry:

	.rodata

msg_hello:
	.byte "Hello, world!", 13, 10, 0
msg_bootingfrom:
	.byte "listing files on device ",0
msg_allfailed:
	.byte 13,10
	.byte "All done.",13,10
	.byte 0
