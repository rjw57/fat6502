	.export irqvector
	.export resetvector
	.export nmivector

	.import reseth

	.code

irqh:
nmih:	rti

	.segment "CPUVECTORS"

	; reset and irq vectors

irqvector:
	.addr irqh
resetvector:
	.addr reseth
nmivector:
	.addr nmih
