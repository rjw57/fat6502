#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <errno.h>

#ifndef u_int32_t
#define u_int32_t unsigned int
#endif

#define fstype_fat12 0x12
#define fstype_fat16 0x16
#define fstype_fat32 0x32

#define byte(BUFFER, OFFSET) (BUFFER[OFFSET])
#define word(BUFFER, OFFSET) (BUFFER[OFFSET] | BUFFER[OFFSET+1]<<8)
#define longword(BUFFER, OFFSET) (BUFFER[OFFSET] | BUFFER[OFFSET+1]<<8 | BUFFER[OFFSET+2]<<16 | BUFFER[OFFSET+3]<<24)


typedef struct fatfs {
  FILE *stream;
  unsigned char sectorbuf[512];
  unsigned char clusterbuf[128*1024];
  int fstype;
  unsigned char secperclus;
  u_int32_t partstart;
  u_int32_t fatstart;
  u_int32_t clusterstart;
  u_int32_t rootdir;
  u_int32_t lba;
  u_int32_t cluster;
} FatFS;



int readsector(int secnum, FatFS *fatfs) {
  int r;

  fatfs->lba = secnum;
  r = fseek(fatfs->stream, secnum * 512, SEEK_SET);
  if (r) {
    perror("seek failed");
    return(r);
  }
  printf("seeking to offset %08x (%d)\n", secnum * 512, secnum * 512);
  r = fread(fatfs->sectorbuf, 512, 1, fatfs->stream);
  printf("read block %08x (%d), %d bytes\n", secnum, secnum, r*512);
  if (r != 1) {
    perror("crapping my pants");
    return(-1);
  } else {
    return(0);
  }
}


int readcluster(int clusternum, FatFS *fatfs) {
  int s, c;
  unsigned char *b = fatfs->clusterbuf;

  s = fatfs->clusterstart + clusternum * fatfs->secperclus;
  printf("reading cluster %08x = sector %08x\n", clusternum, s);
  for (c = s; c < s + fatfs->secperclus; ++c) {
    printf("reading sector %08x\n", c);
    if (readsector(c, fatfs) < 0) {
      return(-1);
    }
    memcpy(b, fatfs->sectorbuf, 512);
    b += 512;
  }
  printf("read %d bytes\n", fatfs->secperclus * 512);
  return(0);
}


int checksignature(FatFS *fatfs) {
  if (fatfs->sectorbuf[0x1fe] == 0x55 && fatfs->sectorbuf[0x1ff] == 0xaa) {
    return(0);
  } else {
    return(-1);
  }
}


int readptable(FatFS *fatfs) {
  unsigned char *p;
  int i = 0;

  fatfs->fstype = 0;

  if (readsector(0, fatfs) < 0) {
    return(-1);
  }

  if (checksignature(fatfs) < 0) {
    return(-1);
  }

  p = fatfs->sectorbuf + 446;
  while (p[4] && i < 4) {
    ++i;
    printf("partition %d: active %02x fstype %02x starts at %08x\n", i, p[0], p[4], p[8] | p[9]<<8 | p[10]<<16 | p[11]<<24);
    if (i == 1) {
      if (p[4] == 0x0c || p[4] == 0x0b) {
	fatfs->partstart = p[8] | p[9]<<8 | p[10]<<16 | p[11]<<24;
	fatfs->fstype = fstype_fat32;
      }
    }
    p += 16;
  }
  return(0);
}


int readvolid(FatFS *fatfs) {
  unsigned char *sbuf = fatfs->sectorbuf;

  if (readsector(fatfs->partstart, fatfs) < 0) {
    printf("read of sector 0x%08x failed\n", fatfs->partstart);
    return(-1);
  }
  if (checksignature(fatfs) < 0) {
    printf("signature failed\n");
    return(-1);
  }

  if (word(sbuf, 0x0b) != 512) {
    printf("sectorsize = %d\n", word(sbuf, 0x0b));
    return(-1);
  }
  if (sbuf[0x10] != 2) {
    printf("%d FATs\n", sbuf[0x10]);
    return(-1);
  }

  fatfs->secperclus = sbuf[0x0d];
  fatfs->fatstart = fatfs->partstart + word(sbuf, 0x0e);
  fatfs->clusterstart = fatfs->fatstart + 2 * (longword(sbuf, 0x24) - fatfs->secperclus);
  fatfs->rootdir = longword(sbuf, 0x2c);

  printf("%d sectors per cluster (%d bytes)\n", fatfs->secperclus,
	 fatfs->secperclus*512);
  printf("FAT starts at sector 0x%08x\n", fatfs->fatstart);
  printf("clusters start at sector 0x%08x\n", fatfs->clusterstart);
  printf("rootdir starts at cluster 0x%08x\n", fatfs->rootdir);

  return(0);
}


void listdirinclusterbuf(FatFS *fatfs) {
  unsigned char *d = fatfs->clusterbuf;
  int i;

  for (;;) {

    if (d[0] == 0) {
      puts("end of directory");
      return;
    }

    if ((d[11] & 0x0f) != 0x0f) {

      putchar('"');
      for (i = 0; i < 8; ++i) {
	putchar(d[i]);
      }
      putchar('.');
      for (i = 8; i < 11; ++i) {
	putchar(d[i]);
      }
      putchar('"');

      if (d[11] == 0x0f) {
	puts(" VFAT");
      } else if (d[11] & 0x08) {
	puts(" VOLID");
      } else {
	printf(" cluster %08x", word(d, 20)<<16 ^ word(d, 26));
	if (d[11] & 0x10) {
	  puts(" DIR");
	} else {
	  printf(" length %d\n", longword(d, 28));
	}
      }
    }
    d += 32;
  }
}


int main(int argc, char **argv) {
  FatFS *fatfs;

  if ((fatfs = malloc(sizeof(*fatfs))) == NULL) {
    printf("not enough ram\n");
    return(1);
  }

  if (argc != 2) {
    printf("usage: fat32readdir raw_device\n");
    return(1);
  }
  if ((fatfs->stream = fopen(argv[1], "r")) == NULL) {
    printf("Couldn't read from %s\n", argv[1]);
    return(1);
  }

  if (readptable(fatfs) < 0) {
    printf("ptable read failed\n");
    return(1);
  }

  if (fatfs->fstype == 0) {
    printf("didn't find a 0x0c fat32 partition\n");
    return(1);
  }

  if (readvolid(fatfs) < 0) {
    printf("couldn't read volid\n");
    return(1);
  }

  if (readcluster(fatfs->rootdir, fatfs) < 0) {
    printf("couldn't read root dir\n");
    return(1);
  }

  listdirinclusterbuf(fatfs);

  if (readcluster(0x00000003, fatfs) < 0) {
    printf("couldn't read boot dir\n");
    return(1);
  }

  listdirinclusterbuf(fatfs);

  fclose(fatfs->stream);
  return(0);
}
