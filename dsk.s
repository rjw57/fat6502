; DSK image handling
;
; Loads/Saves CPC DSK images in system ram
; A volume must be selected and initialized first


  	.include "drivecpu.i"


	.export dsk_load
	.export dsk_save


	.import cluster
	.import clusterbuf

	.import vol_read_clust
	.import vol_write_clust
	.import vol_next_clust
	.import vol_secperclus

	.import stat_length
	.import stat_cluster

	.importzp clusterptr

	.import debug_puts
	.import debug_puthex
	.import debug_crlf


	.bss

loadaddress:	.res 4	; 32-bit load address


	.segment "DSKVECTORS"

dsk_load:	 jmp _dsk_load
dsk_save:	 jmp _dsk_save


	.code


; set loadaddress and start cluster
init:
	ldx #3
@ldsk:	lda #0
	sta loadaddress,x
	lda stat_cluster,x
	sta cluster,x
	dex
	bpl @ldsk
	rts


; Save a DSK image from system ram at $00000
; stat_cluster should point to the first cluster of the DSK file
_dsk_save:
	jsr init		; set loadaddress and start cluster

@nextcluster:
	ldax #clusterbuf
	stax clusterptr		; point to beginning of buffer

	ldy #0
@save:
	lam loadaddress		; load from mem 
	sta (clusterptr),y	; store in buffer

	inc loadaddress		; increment our byte counter
	bne :+
	inc loadaddress+1
	bne :+
	inc loadaddress+2
	;bne :+			; uncomment for 32-bit loads
	;inc loadaddress+3
:
	lda loadaddress		; see if we're done uploading
	cmp stat_length
	bne @next
	lda loadaddress+1
	cmp stat_length+1
	bne @next
	lda loadaddress+2
	cmp stat_length+2
	bne @next
	;lda loadaddress+3	; uncomment for 32-bit loads
	;cmp stat_length+3
	;bne @next

;	ldax #msg_savecluster
;	jsr debug_puts
;	ldx #3
;:	lda cluster,x
;	jsr debug_puthex
;	dex
;	bpl :-
;	jsr debug_crlf

	ldax #clusterbuf	; point to beginning of buffer
	stax clusterptr
	jmp vol_write_clust	; save last cluster

@next:
	iny
	bne @save
	inc clusterptr+1

	lda vol_secperclus	; check for end of cluster
	asl
	;clc
	adc #>clusterbuf
	cmp clusterptr+1
	bne @save

;	ldax #msg_savecluster
;	jsr debug_puts
;	ldx #3
;:	lda cluster,x
;	jsr debug_puthex
;	dex
;	bpl :-
;	jsr debug_crlf

	ldax #clusterbuf	; point to beginning of buffer
	stax clusterptr
	jsr vol_write_clust
	bcs @error

	jsr vol_next_clust	; find next cluster in chain
	bcs @error
	bne @nextcluster
	;beq @eoferror		; premature end of file
@eoferror:
@error:
	sec
	rts


; Load a DSK image to system ram at $00000
; stat_cluster should point to the first cluster of the DSK file
_dsk_load:
	jsr init		; set loadaddress and start cluster

; load routine for dskimage
@nextcluster:
	ldax #msg_loadcluster
	jsr debug_puts
	ldx #3
:	lda cluster,x
	jsr debug_puthex
	dex
	bpl :-
	jsr debug_crlf

	ldax #clusterbuf
	stax clusterptr		; load to clusterbuf
	jsr vol_read_clust	; read the cluster
	bcs @error

	ldax #clusterbuf
	stax clusterptr		; point to beginning of buffer

	ldy #0
@load:
	lda (clusterptr),y	; load from buffer
	sam loadaddress		; store in mem 

	inc loadaddress		; increment our byte counter
	bne :+
	inc loadaddress+1
	bne :+
	inc loadaddress+2
	;bne :+			; uncomment for 32-bit loads
	;inc loadaddress+3
:
	lda loadaddress		; see if we're done uploading
	cmp stat_length
	bne @next
	lda loadaddress+1
	cmp stat_length+1
	bne @next
	lda loadaddress+2
	cmp stat_length+2
	bne @next
	;lda loadaddress+3	; uncomment for 32-bit loads
	;cmp stat_length+3
	;bne @next

	clc
	rts

@next:
	iny
	bne @load
	inc clusterptr+1

	lda vol_secperclus	; check for end of cluster
	asl
	;clc
	adc #>clusterbuf
	cmp clusterptr+1
	bne @load

	jsr vol_next_clust	; find next cluster in chain
	bcs @error
	bne @nextcluster
	;beq @eoferror		; premature end of file
@eoferror:
@error:
	sec
	rts


	.rodata

msg_loadcluster:
	.byte "reading cluster ", 0
msg_savecluster:
	.byte "writing cluster ", 0
