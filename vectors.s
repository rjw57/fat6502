	.export irqvector
	.export resetvector
	.export nmivector

	.import reseth

	.code

irqh:
nmih:	rti
	
	.segment "VECTORS"

irqvector:
	.addr irqh
resetvector:
	.addr reseth
nmivector:
	.addr nmih
