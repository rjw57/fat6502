; IDE register map
ide_data	= 0	; r/w
ide_error	= 1	; r
ide_features	= 1	; w
ide_scount	= 2	; r/w
ide_lba0	= 3	; r/w
ide_lba1	= 4	; r/w
ide_lba2	= 5	; r/w
ide_lba3	= 6	; r/w
ide_status	= 7	; r
ide_command	= 7	; w

; IDE commands
idecmd_read_sector	= $20
idecmd_packet		= $a0
idecmd_identify		= $ec
idecmd_identifypacket	= $a1

; ATAPI commands
atapicmd_read	= $28

def_ide_channel	= $08	; we'll boot from secondary
def_ide_device	= $00	; we'll boot from master. slave = $10
