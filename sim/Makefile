CC = gcc
CFLAGS = -O3 -DLSB_FIRST -DDEBUG

%.o: %c
	$(CC) $(CFLAGS) -c $<

all: drivesim

drivesim: drivesim.o M6502.o Debug.o
	$(CC) -o drivesim $^

dasm: dasm.c
	$(CC) -o dasm dasm.c

M6502.o: M6502.c M6502.h Tables.h Codes.h
Debug.o: Debug.c M6502.h

clean:
	rm -f drivesim *.o
