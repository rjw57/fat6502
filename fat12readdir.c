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


typedef struct fat12fs {
  FILE *stream;
  unsigned char sectorbuf[512];
  unsigned char clusterbuf[512];
  int fstype;
  unsigned char secperclus;
  u_int16_t fatstart;
  u_int16_t clusterstart;
  u_int16_t rootdir;
  u_int16_t lba;
  u_int16_t cluster;
} Fat12FS;



int readsector(int secnum, Fat12FS *fatfs) {
  int r;

  fatfs->lba = secnum;
  r = fseek(fatfs->stream, secnum * 512, SEEK_SET);
  if (r) {
    perror("seek failed");
    return(r);
  }
  // printf("seeking to offset 0x%04x (%d)\n", secnum * 512, secnum * 512);
  r = fread(fatfs->sectorbuf, 512, 1, fatfs->stream);
  // printf("read block 0x%04x (%d), %d bytes\n", secnum, secnum, r*512);
  if (r != 1) {
    perror("crapping my pants");
    return(-1);
  } else {
    return(0);
  }
}


int readrootdir(Fat12FS *fatfs) {
  readsector(fatfs->rootdir, fatfs);
  memcpy(fatfs->clusterbuf, fatfs->sectorbuf, 512);
  return(0);
}


int readcluster(int clusternum, Fat12FS *fatfs) {
  int s, c;
  unsigned char *b = fatfs->clusterbuf;

  if (clusternum == 0) {
    s = fatfs->rootdir;
  } else {
    clusternum -= 2;
    s = fatfs->clusterstart + clusternum * fatfs->secperclus;
  }
  printf("reading cluster 0x%04x = sector 0x%04x\n", clusternum, s);
  for (c = s; c < s + fatfs->secperclus; ++c) {
    printf("reading sector 0x%04x\n", c);
    if (readsector(c, fatfs) < 0) {
      return(-1);
    }
    memcpy(b, fatfs->sectorbuf, 512);
    b += 512;
  }
  printf("read %d bytes\n", fatfs->secperclus * 512);
  return(0);
}


int checksignature(Fat12FS *fatfs) {
  if (fatfs->sectorbuf[0x1fe] == 0x55 && fatfs->sectorbuf[0x1ff] == 0xaa) {
    return(0);
  } else {
    return(-1);
  }
}


int readbootblock(Fat12FS *fatfs) {
  unsigned char *sbuf = fatfs->sectorbuf;

  if (readsector(0, fatfs) < 0) {
    printf("read of sector 0x%04x failed\n", 0);
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

  printf("%d sectors per fat\n", word(sbuf, 0x16));
  printf("%d entries in root dir (%d sectors)\n", word(sbuf, 0x11), word(sbuf, 0x11)/16);
  fatfs->secperclus = sbuf[0x0d];
  fatfs->fatstart = word(sbuf, 0x0e);
  fatfs->rootdir = fatfs->fatstart + 2 * word(sbuf, 0x16);
  fatfs->clusterstart = fatfs->rootdir + word(sbuf, 0x11) / 16;

  printf("%d sectors per cluster (%d bytes)\n", fatfs->secperclus,
	 fatfs->secperclus*512);
  printf("FAT starts at sector 0x%04x\n", fatfs->fatstart);
  printf("rootdir starts at cluster 0x%04x\n", fatfs->rootdir);
  printf("clusters start at sector 0x%04x\n", fatfs->clusterstart);

  return(0);
}


u_int16_t nextclusterinchain(u_int16_t cluster, Fat12FS *fatfs) {
  unsigned int fptr = fatfs->fatstart;
  int offset = 3 * cluster / 2;

  while (offset > 512) {
    ++fptr;
    offset -= 512;
  }

  if (readsector(fptr, fatfs) < 0) {
    printf("coultn't read fat sector %d\n", fptr);
    return(0);
  }

  // does not handle clusters that go across sector boundaries
  if (cluster & 1) {
    return((word(fatfs->sectorbuf, offset)>>4) & 0x0fff);
  } else {
    return(word(fatfs->sectorbuf, offset) & 0x0fff);
  }
}


void followclusterchain(u_int16_t cluster, Fat12FS *fatfs) {
  u_int16_t c = cluster;
  int bailout = 0;

  if (c == 0) {
    printf("0x0000\n");
    return;
  }

  while (c && ((c & 0x0fff) < 0x0ff0) && bailout++ < 10) {
    printf(" 0x%04x", c);
    c = nextclusterinchain(c, fatfs);
  }
  puts("");
}


void listdirinclusterbuf(Fat12FS *fatfs) {
  unsigned char *d = fatfs->clusterbuf;
  int i;

  for (;;) {

    if (d[0] == 0) {
      puts("end of directory");
      return;
    }

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
      printf(" VFAT");
    } else if (d[11] & 0x10) {
      printf(" DIR");
    } else {
      printf("    ");
    }

    printf(" %4d kB start cluster 0x%04x", word(d, 0x1c) / 1024, word(d, 0x1a));
    puts("");

    followclusterchain(word(d, 0x1a), fatfs);

    d += 32;
  }
}


int main(int argc, char **argv) {
  Fat12FS *fatfs;

  if ((fatfs = malloc(sizeof(*fatfs))) == NULL) {
    printf("not enough ram\n");
    return(1);
  }

  if (argc != 2) {
    printf("usage: fat12readdir raw_device\n");
    return(1);
  }
  if ((fatfs->stream = fopen(argv[1], "r")) == NULL) {
    printf("Couldn't read from %s\n", argv[1]);
    return(1);
  }

  fatfs->fstype = 1;

  if (readbootblock(fatfs) < 0) {
    printf("couldn't read boot block\n");
    return(1);
  }

  if (readcluster(0, fatfs) < 0) {
    printf("couldn't read root dir\n");
    return(1);
  }

  listdirinclusterbuf(fatfs);

  if (readcluster(2, fatfs) < 0) {
    printf("couldn't read boot dir\n");
    return(1);
  }

  listdirinclusterbuf(fatfs);

  fclose(fatfs->stream);
  return(0);
}
