; risc code optimizations

	.include "drivecpu.i"


	.export risc_read_256_words


	.importzp sectorptr
	.import ide_channel


	.zeropage

codeptr:	.res 2

	.bss

risc_sel_read_256_words = 1

risc_selected:	.res 1
opaddress:	.res 3


	.code

risc_read_256_words:
	lda risc_selected	; check if opcode is prepared
	cmp #risc_sel_read_256_words
	beq @selected

	; redefine 6502 opcode $02
	ldax #risc_code_read_256_words
	stax codeptr
	lda #$40		; $082040 for opcode $02
	sta opaddress
	lda #$20		; $0820xx for 6502
	sta opaddress+1
	lda #$08		; $08xxxx for riscemucode
	sta opaddress+2
	ldy #0
:	lda (codeptr),y		; grab a byte
	sam opaddress		; store it in system ram
	inc opaddress		; increment our byte counter
	iny
	cpy #$60		; overwrite opcodes 02/03/04
	bne :-

	lda #risc_sel_read_256_words
	sta risc_selected

@selected:
	lda #7
:	.byte $02, <sectorptr, >sectorptr
	bne :-
	rts

risc_code_read_256_words:	;RISCcode for reading 256 words
;get (sectorptr) and store pc in riscregs $0E and $0F
	.byte $E2	;LD	(PC++)
	.byte $6C	;ST	0C
	.byte $E2	;LD	(PC++)
	.byte $F5	;EX	PCH
	.byte $6F	;ST	0F
	.byte $4C	;LD	0C
	.byte $F4	;EX	PCL
	.byte $6E	;ST	0E
;get sectorptr and store it in riscregs $0C and $0D
	.byte $E2	;LD	(PC++)
	.byte $6C	;ST	0C
	.byte $E2	;LD	(PC++)
	.byte $6D	;ST	0D
;put $FC02 into PC
	.byte $B0	;LD	#00
	.byte $02	;ADD	#02
	.byte $F4	;EX	PCL
	.byte $BF	;LD	#F0
	.byte $0C	;ADD	#0C
	.byte $F5	;EX	PCH
;out $0F to $FC02, in $FC02 set the IDEADR, in this case statusreg
	.byte $B0	;LD	#00
	.byte $0F	;ADD	#0F
	.byte $E7	;OUT	(PC)
;set IO_RD to L
	.byte $BE	;LD	#E0
	.byte $09	;ADD	#09
	.byte $F8	;ST	MB
;wait 400ns include 2 x decrement pc
	.byte $20	;JRNZ	#00
	.byte $FB	;PC--
	.byte $FB	;PC--
;read lbyte from IDE-databus($FC00) and store in A(is riscreg $09)
	.byte $E6	;IN	(PC++)
	.byte $69	;ST	A
;set IO_RD to H
	.byte $BC	;LD	#C0
	.byte $09	;ADD	#09
	.byte $F8	;ST	MB
;test status
	.byte $B0	;LD	#00
	.byte $08	;ADD	#08
	.byte $99	;AND	A
	.byte $26	;JRNZ	#06
;not ready
	.byte $4E,$F4,$4F,$F5 ;POP	PC
	.byte $E2,$F1	;NEXT

;ready
;out $08 to $FC02, in $FC02 set the IDEADR, in this case datareg
	.byte $FA	;PC++
	.byte $E7	;OUT	(PC)
;set IO_RD to L
	.byte $BE	;LD	#E0
	.byte $09	;ADD	#09
	.byte $F8	;ST	MB
;wait 400ns include 2 x decrement pc
	.byte $20	;JRNZ	#00
	.byte $FB	;PC--
	.byte $FB	;PC--
;read lbyte from IDE-databus($FC00) and store in A(is riscreg $09)
	.byte $E6	;IN	(PC++)
	.byte $69	;ST	A
;set IO_RD to H
	.byte $BC	;LD	#C0
	.byte $09	;ADD	#09
	.byte $F8	;ST	MB
;read hbyte from IDE-databus($FC01) and store in P(is riscreg $08) - use as tmp
	.byte $E6	;IN	(PC++)
	.byte $68	;ST	P
;get sectorptr
	.byte $4C	;LD	0C
	.byte $F4	;EX	PCL
	.byte $4D	;LD	0D
	.byte $F5	;EX	PCH
;get Y
	.byte $45	;LD	Y
;make (sectorptr),2 x Y (2 x PC=PC+Y)
	.byte $FF	;ADDU
	.byte $FF	;ADDU	
;store lbyte to ram
	.byte $49	;LD	A
	.byte $E3	;ST	(PC)
;store hbyte to ram
	.byte $48	;LD	P
	.byte $FA	;PC++
	.byte $E3	;ST	(PC)
;reatore PC
	.byte $4E,$F4,$4F,$F5 ;POP	PC
;	iny
	.byte $45	;LD	Y
	.byte $01	;ADD	#01
	.byte $65	;ST	Y
;set flags
	.byte $F2	;FLAGSV
	.byte $68	;ST	P
	.byte $E2,$F1	;NEXT
