	.export resetvector
	.export warmstartvector
	.export irqvector

	.import reseth
	.import warmstart

	.segment "CPUVECTORS"

	; reset and irq vectors

warmstartvector:
	.addr warmstart
resetvector:
	.addr reseth
irqvector:
	.addr 0
