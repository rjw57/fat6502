#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "M6502.h"


#ifndef FAST_RDOP
#define Op6502(A) Rd6502(A)
#endif


#define CPUSPEED 2

static byte ident_hd[512] = {
  0x04, 0x5a, 0x3f, 0xff, 0x00, 0x00, 0x00, 0x10, 0x7e, 0x00, 0x53, 0x32, 0x00, 0x3f, 0x00, 0x00,
  0x00, 0x00, 0x51, 0x54, 0x31, 0x37, 0x34, 0x30, 0x31, 0x31, 0x38, 0x32, 0x36, 0x37, 0x30, 0x39,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x03, 0x03, 0x44, 0x00, 0x04, 0x41, 0x30,
  0x33, 0x2e, 0x30, 0x39, 0x30, 0x30, 0x51, 0x55, 0x41, 0x4e, 0x54, 0x55, 0x4d, 0x20, 0x46, 0x49,
  0x52, 0x45, 0x42, 0x41, 0x4c, 0x4c, 0x6c, 0x63, 0x74, 0x31, 0x30, 0x20, 0x32, 0x30, 0x20, 0x20,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x80, 0x10,
  0x00, 0x00, 0x0f, 0x00, 0x40, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x07, 0x3f, 0xff, 0x00, 0x10,
  0x00, 0x3f, 0xfc, 0x10, 0x00, 0xfb, 0x01, 0x00, 0x77, 0x80, 0x02, 0x60, 0x00, 0x00, 0x04, 0x07,
  0x00, 0x03, 0x00, 0x78, 0x00, 0x78, 0x00, 0x78, 0x00, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x03, 0x00, 0x78, 0x00, 0x78, 0x00, 0x78, 0x00, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x1e, 0x00, 0x11, 0x34, 0x6b, 0x40, 0x01, 0x40, 0x00, 0x34, 0x69, 0x00, 0x01, 0x40, 0x00,
  0x00, 0x1f, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0xff, 0xfe, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static byte ident_cd[512] = {
  0x85, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x59, 0x48,
  0x30, 0x58, 0x20, 0x20, 0x20, 0x20, 0x4c, 0x54, 0x4e, 0x35, 0x32, 0x36, 0x20, 0x20, 0x20, 0x20,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
  0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x00, 0x00,
  0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x01, 0x07,
  0x00, 0x03, 0x00, 0x78, 0x00, 0x78, 0x00, 0x78, 0x00, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x02, 0x00, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x02, 0x00, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};


static byte Cycles[256] =
{
  7,6,2,8,3,3,5,5,3,2,2,2,4,4,6,6,
  2,5,2,8,4,4,6,6,2,4,2,7,5,5,7,7,
  6,6,2,8,3,3,5,5,4,2,2,2,4,4,6,6,
  2,5,2,8,4,4,6,6,2,4,2,7,5,5,7,7,
  6,6,2,8,3,3,5,5,3,2,2,2,3,4,6,6,
  2,5,2,8,4,4,6,6,2,4,2,7,5,5,7,7,
  6,6,2,8,3,3,5,5,4,2,2,2,5,4,6,6,
  2,5,2,8,4,4,6,6,2,4,2,7,5,5,7,7,
  2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,
  2,6,2,6,4,4,4,4,2,5,2,5,5,5,5,5,
  2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,
  2,5,2,5,4,4,4,4,2,4,2,5,4,4,4,4,
  2,6,2,8,3,3,5,5,2,2,2,2,4,4,6,6,
  2,5,2,8,4,4,6,6,2,4,2,7,5,5,7,7,
  2,6,2,8,3,3,5,5,2,2,2,2,4,4,6,6,
  2,5,2,8,4,4,6,6,2,4,2,7,5,5,7,7
};


struct c1io {
  /* csa */
  unsigned char ide_addr;    /* IDE A0..A2*/
  unsigned char ide_channel; /* IDE channel */
  unsigned char cpudma;      /* CPU DMA line */
  unsigned long fpgabyte;    /* FPGA byte counter */
  unsigned char ide_dev;     /* master or slave */

  /* ide regs */
  unsigned char idereg[2][8];

  /* sab/sau/sal */
  unsigned long sysramaddr;

} C1IO;
unsigned char *mem;
static unsigned long tracereg = 0;
static const char *usage = "Usage: drivesim [-l address] [-e address] [-p] [-s] driverom hdimage cdimage";
int hd = 0;
int iso = 0;
unsigned char sectorbuf[2048];
int sbufctr, sbufsize;
int dopause = 1;
int exitnow = 0;
int silent = 0;
unsigned char hdsig[] = { 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x40 };
unsigned char cdsig[] = { 0x80, 0x01, 0x01, 0x01, 0x14, 0xeb, 0xf0, 0x40 };


void ResetIDE(void) {
  int d, r;

  C1IO.ide_addr = 0;
  C1IO.ide_channel = 0;
  C1IO.cpudma = 0;
  C1IO.fpgabyte = 0;
  C1IO.ide_dev = 0;
  C1IO.sysramaddr = 0;

  for (r = 0; r < 8; ++r) {
    C1IO.idereg[0][r] = 0x7f;
    C1IO.idereg[1][r] = hdsig[r];
  }
}

int waitkey(void) {
  if (dopause) {
    return(getchar());
  } else {
    return(10);
  }
}


byte Rd6502(register word Addr) {
  switch (Addr) {

  case 0x3f25:
    return(0x20);
    break;

  case 0x3f26:
    return(0x10);
    break;

  default:
    return(mem[Addr]);
    break;

  }
}


void Wr6502(register word Addr, register byte Value) {
  switch (Addr) {

  case 0x3f20:
    if ((mem[0x3f23] & 0x80) == 0) {
      putchar(Value);
    }
    break;

  default:
    mem[Addr] = Value;
    break;

  }
}


byte Loop6502(register M6502 *R) {
  return(INT_NONE);
}


byte Patch6502(register byte Op,register M6502 *R) {
  unsigned char l, h;
  unsigned long offs;
  int i;

  switch(Op) {

  case 0x12: /* saf */
    if (!silent) printf("!FPGA store byte %d data %d\n", C1IO.fpgabyte++, R->A);
    break;

  case 0x1a: /* ist */
    if (!silent) printf("!IDE write to reg %d channel %d data %04x\n",
	   C1IO.ide_addr, C1IO.ide_channel, R->A | R->X<<8);
    if (C1IO.ide_channel == 0) {

    } else {

      if (C1IO.ide_addr == 0) {
	if (C1IO.idereg[C1IO.ide_channel][7] == 0x08) {
	  if (sbufctr < sbufsize) {
	    sectorbuf[sbufctr++] = R->A;
	    sectorbuf[sbufctr++] = R->X;
	    if (sbufctr == sbufsize) {
	      // received packet command

	      if (!silent) printf("!IDE ATAPI packet command: 0x%02x\n", sectorbuf[0]);

	      switch (sectorbuf[0]) {

		// read sector
	      case 0x28:
		offs = 2048 * (sectorbuf[2]<<24 | sectorbuf[3]<<16 |
			       sectorbuf[4]<<8 | sectorbuf[5]);
		if (lseek(iso, offs, SEEK_SET) != offs) {
		  if (!silent) printf("!IDE ATAPI Seek failed for offset %d\n", offs);
		}
		if (read(iso, &sectorbuf, 2048) != 2048) {
		  if (!silent) printf("!IDE ATAPI Read failed for sector %d\n", offs / 2048);
		  C1IO.idereg[C1IO.ide_channel][7] = 0x41;
		} else {
		  if (!silent) printf("!IDE ATAPI Read sector %d\n", offs / 2048);
		  C1IO.idereg[C1IO.ide_channel][7] = 0x08;
		  sbufctr = 0;
		  sbufsize = 2048;
		}
	      
		break;

	      default:
		if (!silent) printf("!IDE unknown atapi packet command: 0x%02x\n", sectorbuf[0]);
		C1IO.idereg[C1IO.ide_channel][7] = 0x41;
		break;

	      }

	    }
	  } else {
	    printf("!IDE writing to data register on channel %d device %d and I don't like that kinda thing\n",
		   C1IO.ide_channel, C1IO.ide_dev);
	    exitnow = 1;
	  }
	} else {
	  printf("!IDE writing to data register on channel %d device %d with no data\n",
		 C1IO.ide_channel, C1IO.ide_dev);
	  exitnow = 1;
	}

      } else if (C1IO.ide_addr == 6) {
	C1IO.ide_dev = (R->A & 0x10)>>4;
	if (!silent) printf("!IDE selected device %d\n", C1IO.ide_dev);

      } else if (C1IO.ide_addr == 7) {

	/* --- IDE commands --- */

	if (!silent) printf("!IDE command: 0x%02x\n", R->A);

	// read sector
	switch (R->A) {

	case 0x20:
	  if (C1IO.ide_channel == 1 && C1IO.ide_dev == 0) {
	    offs = 512 * (C1IO.idereg[C1IO.ide_channel][3] |
			  C1IO.idereg[C1IO.ide_channel][4]<<8 |
			  C1IO.idereg[C1IO.ide_channel][5]<<16 |
			  (C1IO.idereg[C1IO.ide_channel][6] & 0x0f)<<24);
	    if (lseek(hd, offs, SEEK_SET) != offs) {
	      if (!silent) printf("!IDE Seek failed for offset %d\n", offs);
	    }
	    if (read(hd, &sectorbuf, 512) != 512) {
	      if (!silent) printf("!IDE Read failed for sector %d\n", offs / 512);
	      C1IO.idereg[C1IO.ide_channel][7] = 0x41;
	    } else {
	      if (!silent) printf("!IDE Read sector %d\n", offs / 512);
	      C1IO.idereg[C1IO.ide_channel][7] = 0x08;
	      sbufctr = 0;
	      sbufsize = 512;
	    }
	  } else {
	    if (!silent) printf("!IDE Read sector on unsupported device\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x41;
	  }
	  break;

	// identify device
	case 0xec:
	  if (C1IO.ide_channel == 1 && C1IO.ide_dev == 0) {
	    if (!silent) printf("!IDE identify device\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x08;
	    sbufctr = 0;
	    sbufsize = 512;
	    for (i = 0; i < 512; ++i) {
	      sectorbuf[i] = ident_hd[i];
	    }
	  } else {
	    if (!silent) printf("!IDE identify device on unsupported device\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x41;
	  }
	  break;

	// packet command
	case 0xa0:
	  if (C1IO.ide_channel == 1 && C1IO.ide_dev == 1) {
	    if (!silent) printf("!IDE packet command\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x08;
	    sbufctr = 0;
	    sbufsize = C1IO.idereg[C1IO.ide_channel][4];
	  } else {
	    if (!silent) printf("!IDE packet command on unsupported device\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x41;
	  }
	  break;

	// identify packet device
	case 0xa1:
	  if (C1IO.ide_channel == 1 && C1IO.ide_dev == 1) {
	    if (!silent) printf("!IDE identify packet device\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x08;
	    sbufctr = 0;
	    sbufsize = 512;
	    for (i = 0; i < 512; ++i) {
	      sectorbuf[i] = ident_cd[i];
	    }
	  } else {
	    if (!silent) printf("!IDE identify packet device on unsupported device\n");
	    C1IO.idereg[C1IO.ide_channel][7] = 0x41;
	  }
	  break;

	// unknown command
	default:
	  if (!silent) printf("!IDE unknown command: 0x%02x\n", R->A);
	  C1IO.idereg[C1IO.ide_channel][7] = 0x41;
	  break;

	}

	/* --- IDE commands --- */

      } else {
	C1IO.idereg[C1IO.ide_channel][C1IO.ide_addr] = R->A;
      }
    }
    break;

  case 0x32: /* lka */
    R->A = 0;
    break;

  case 0x3a: /* ild */
    if (C1IO.ide_channel == 0) {
      R->A = 0x7f;
      R->X = 0;
    } else {
      if (C1IO.ide_addr == 0) {
	if (C1IO.idereg[C1IO.ide_channel][7] & 0x08) { /* if DRQ is set */
	  R->A = sectorbuf[sbufctr++];
	  R->X = sectorbuf[sbufctr++];

	  if (sbufctr == sbufsize) {
	    C1IO.idereg[C1IO.ide_channel][7] = 0x40;
	  }

	} else {
	  printf("!IDE Reading from data register on channel %d device %d with no data\n",
		 C1IO.ide_channel, C1IO.ide_dev);
	  exitnow = 1;
	}
      } else {
	R->A = C1IO.idereg[C1IO.ide_channel][C1IO.ide_addr];
	R->X = 0;
      }
    }
    if (!silent) printf("!IDE read from channel %d device %d reg %d data %04x\n",
	   C1IO.ide_channel, C1IO.ide_dev, C1IO.ide_addr, R->A | R->X<<8);
    break;

  case 0x52: /* sab */
    C1IO.sysramaddr = C1IO.sysramaddr & 0x0000ffffL | (R->A)<<16;
    break;

  case 0x5a: /* csa */
    l = R->A;
    C1IO.ide_addr = l & 7;
    C1IO.ide_channel = (l & 8)>>3;
    C1IO.cpudma = (l & 16)>>4;
    if ((l & 32) == 0) {
      C1IO.fpgabyte = 0;
      if (!silent) printf("!FPGA erased\n");
    }
    if (!silent) printf("!ide_addr = %d, ide_channel = %d, cpudma = %d\n",
	   C1IO.ide_addr, C1IO.ide_channel, C1IO.cpudma);
    if (C1IO.cpudma) exitnow = 1;
    break;

  case 0x72: /* sau */
    C1IO.sysramaddr = C1IO.sysramaddr & 0x00ff00ffL | (R->A)<<8;
    break;

  case 0x92: /* sal */
    C1IO.sysramaddr = C1IO.sysramaddr & 0x00ffff00L | (R->A);
    break;

  case 0xd2:    /* mld */
    break;

  case 0xf2:    /* mst */
    break;

  case 0xf3: /* tr0 */
    l = Op6502(R->PC.W++);
    h = Op6502(R->PC.W++);
    tracereg = tracereg & 0x00ffffffL | Rd6502(l | h<<8)<<24;
    break;

  case 0xf4: /* tr1 */
    l = Op6502(R->PC.W++);
    h = Op6502(R->PC.W++);
    tracereg = tracereg & 0xff00ffffL | Rd6502(l | h<<8)<<16;
    break;

  case 0xfa: /* tr2 */
    l = Op6502(R->PC.W++);
    h = Op6502(R->PC.W++);
    tracereg = tracereg & 0xffff00ffL | Rd6502(l | h<<8)<<8;
    break;

  case 0xfb: /* tr3 */
    l = Op6502(R->PC.W++);
    h = Op6502(R->PC.W++);
    tracereg = tracereg & 0xffffff00L | Rd6502(l | h<<8);
    break;

  case 0xff: /* trc */
    l = Op6502(R->PC.W++);
    //silent = 0;
    R->Trace = 1; /* enter monitor */
    printf("!TRC %02x %08x\n", l, tracereg);
    /*
    if (l == 0xff || l == 0xfe) {
      if (!silent) printf("Execution done at %04x\n", R->PC.W);
      exitnow = 1;
    } else {
      l = waitkey();
    }
    */
    break;

  defalt:
    return(0);
    break;

  }

  return(1);
}


void printbin(unsigned char b) {
  int c;

  for (c = 7; c >= 0; --c) {
    if (b & 1<<c) {
      putchar('1');
    } else {
      putchar('0');
    }
  }
}


void printregs(M6502 *R) {
  puts(" ADDR AC XR YR SP NV-BDIZC");
  if (!silent) printf(";%04x %02x %02x %02x %02x ", R->PC.W, R->A, R->X, R->Y, R->S);
  printbin(R->P);
  puts("");
}


void simulate(M6502 *R) {
  char s[128];
  int l, i;
  int x;
  unsigned long instctr = 0, cyclectr = 0;

  while (!exitnow) {
    if (!silent) printregs(R);
    l = DAsm(s, R->PC.W);
    if (!silent) printf(".%04x  ", R->PC.W);
    for (i = 0; i < 3; ++i) {
      if (i < l) {
	if (!silent) printf("%02x ", Rd6502(R->PC.W + i));
      } else {
	if (!silent) printf("   ");
      }
    }
    if (!silent) printf(" %s\n", s);
    cyclectr += Cycles[Rd6502(R->PC.W)];
    ++instctr;
    Exec6502(R);

    /* Turn tracing on when reached trap address */
    if (R->PC.W == R->Trap) R->Trace=1;
    /* Call single-step debugger, exit if requested */
    if (R->Trace) {
      if (!Debug6502(R)) return;
    } else {
      if (!silent) puts("");
    }
  }

  printf("\nExecuted %d instructions, %d cycles, %.2f seconds\n", instctr, cyclectr,
	 ((double) cyclectr) / ((double) CPUSPEED * 1000000));

  return;
}


int main (int argc, char **argv) {
  int a;
  char *driveromname = NULL;
  char *hdimagename = NULL;
  char *isoimagename = NULL;
  int romaddr = -1;
  int execaddr = -1;
  int fh;
  struct stat finfo;
  M6502 *R;

  puts("C1 drive CPU simulator v0.1");
  puts("Based on the M6502 core by Marat Fayzullin");
  puts("");

  if (argc < 4) {
    puts(usage);
    return(1);
  }

  /* parse args */
  for (a = 1; a < argc - 2; ++a) {
    if (a == argc - 3) {
      if (argv[a][0] == '-') {
	puts(usage);
	return(1);
      }
      driveromname = argv[a];
      hdimagename = argv[a + 1];
      isoimagename = argv[a + 2];
      a += 2;
    } else {
      if (argv[a][0] != '-') {
	puts(usage);
	return(1);
      }
      if (strlen(argv[a]) != 2) {
	puts(usage);
	return(1);
      }
      switch(argv[a][1]) {

      case 'l':
	if (a >= argc - 3) {
	  puts(usage);
	  return(1);
	}
	romaddr = strtol(argv[a + 1], (char **)NULL, 0);
	++a;
	break;

      case 'e':
	if (a >= argc - 3) {
	  puts(usage);
	  return(1);
	}
	execaddr = strtol(argv[a + 1], (char **)NULL, 0);
	++a;
	break;

      case 'p':
	dopause = 0;
	break;

      case 's':
	silent = 1;
	break;

      default:
	puts(usage);
	return(1);
	break;

      }
    }
  }

  if (stat(driveromname, &finfo)) {
    printf("Couldn't open %s\n", driveromname);
    return(2);
  }

  if (finfo.st_size > 65536) {
    printf("%s is larger than 64 kB\n", driveromname);
    return(2);
  }
  if (romaddr < 0) {
    romaddr = 65536 - finfo.st_size;
  } else {
    if (finfo.st_size + romaddr > 65536) {
      printf("Can't load %s at 0x%04x, file is too large\n", driveromname, romaddr);
      return(2);
    }
  }

  if ((mem = malloc(65536)) == NULL) {
    puts("Out of memory");
    return(3);
  }

  if ((fh = open(driveromname, O_RDONLY)) < 0) {
    printf("Couldn't open %s\n", driveromname);
    free(mem);
    return(2);
  }

  printf("loading %s at 0x%04x\n", driveromname, romaddr);
  if (read(fh, mem + romaddr, finfo.st_size) != finfo.st_size) {
    printf("Couldn't open %s\n", driveromname);
    close(fh);
    free(mem);
    return(2);
  }

  if ((hd = open(hdimagename, O_RDONLY)) < 0) {
    printf("Couldn't open %s\n", hdimagename);
    close(fh);
    free(mem);
    return(4);
  }

  if ((iso = open(isoimagename, O_RDONLY)) < 0) {
    printf("Couldn't open %s\n", isoimagename);
    close(hd);
    close(fh);
    free(mem);
    return(4);
  }

  if (execaddr < 0) {
    execaddr = mem[0xfffc] | mem[0xfffd]<<8;
  }
  printf("executing from 0x%04x\n\n", execaddr);

  if ((R = malloc(sizeof(*R))) == NULL) {
    puts("Out of memory");
    close(iso);
    close(fh);
    close(hd);
    free(mem);
    return(3);
  }
  ResetIDE();
  Reset6502(R);
  R->PC.W = execaddr;
  simulate(R);

  if (R) free(R);
  if (fh) close(fh);
  if (hd) close(hd);
  if (iso) close(iso);
  if (mem) free(mem);
  return(0);
}
