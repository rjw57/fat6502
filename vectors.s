	.export resetvector
	.export warmstartvector

	.import reseth
	.import warmstart

	.segment "CPUVECTORS"

	; reset and irq vectors

irqvector:
	.addr 0
resetvector:
	.addr reseth
warmstartvector:
	.addr warmstart
