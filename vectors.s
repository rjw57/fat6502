	.import reseth

	.code

irqh:
nmih:	rti
	
	.segment "VECTORS"

	.addr irqh
	.addr reseth
	.addr nmih
