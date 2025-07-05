PREFIX ?= /opt/local
CC ?= gcc
INSTALLDIR = $(DESTDIR)$(PREFIX)/lib
INSTALLNAME = $(PREFIX)/lib/libsc68.dylib

CFLAGS += -Wall -fPIC \
  -Ilibsc68 \
  -Ilibsc68/file68 \
  -Ilibsc68/file68/src \
  -Ilibsc68/file68/sc68 \
  -Ilibsc68/libsc68 \
  -Ilibsc68/libsc68/dial68 \
  -Ilibsc68/libsc68/emu68 \
  -Ilibsc68/libsc68/io68 \
  -Ilibsc68/libsc68/sc68 \
  -Ilibsc68/unice68 \
  -Ilibsc68/desa68 \
  -DHAVE_STDLIB_H \
  -DHAVE_STDINT_H \
  -DHAVE_STRING_H \
  -DHAVE_LIMITS_H \
  -DHAVE_ASSERT_H \
  -DHAVE_BASENAME \
  -DHAVE_LIBGEN_H \
  -DEMU68_MONOLITIC \
  -DEMU68_EXPORT \
  -DUSE_UNICE68

SRC = \
  libsc68/file68/src/gzip68.c \
  libsc68/file68/src/vfs68.c \
  libsc68/file68/src/ice68.c \
  libsc68/file68/src/vfs68_ao.c \
  libsc68/file68/src/vfs68_null.c \
  libsc68/file68/src/msg68.c \
  libsc68/file68/src/timedb68.c \
  libsc68/file68/src/init68.c \
  libsc68/file68/src/vfs68_z.c \
  libsc68/file68/src/replay68.c \
  libsc68/file68/src/registry68.c \
  libsc68/file68/src/uri68.c \
  libsc68/file68/src/rsc68.c \
  libsc68/file68/src/vfs68_fd.c \
  libsc68/file68/src/vfs68_file.c \
  libsc68/file68/src/vfs68_mem.c \
  libsc68/file68/src/file68.c \
  libsc68/file68/src/string68.c \
  libsc68/file68/src/endian68.c \
  libsc68/file68/src/vfs68_curl.c \
  libsc68/file68/src/option68.c \
  libsc68/file68/src/ferror68.c \
  libsc68/libsc68/dial68/dial68.c \
  libsc68/libsc68/dial68/dial_conf.c \
  libsc68/libsc68/dial68/dial_finf.c \
  libsc68/libsc68/dial68/dial_tsel.c \
  libsc68/unice68/unice68_unpack.c \
  libsc68/unice68/unice68_pack.c \
  libsc68/unice68/unice68_version.c \
  libsc68/libsc68/conf68.c \
  libsc68/libsc68/api68.c \
  libsc68/libsc68/mixer68.c \
  libsc68/libsc68/io68/paulaemul.c \
  libsc68/libsc68/io68/ym_envel.c \
  libsc68/libsc68/io68/ymemul.c \
  libsc68/libsc68/io68/shifter_io.c \
  libsc68/libsc68/io68/paula_io.c \
  libsc68/libsc68/io68/mw_io.c \
  libsc68/libsc68/io68/ym_dump.c \
  libsc68/libsc68/io68/mfp_io.c \
  libsc68/libsc68/io68/mwemul.c \
  libsc68/libsc68/io68/ym_io.c \
  libsc68/libsc68/io68/io68.c \
  libsc68/libsc68/io68/ym_blep.c \
  libsc68/libsc68/io68/mfpemul.c \
  libsc68/libsc68/io68/ym_puls.c \
  libsc68/libsc68/libsc68.c \
  libsc68/libsc68/emu68/lines68.c \
  libsc68/libsc68/emu68/ioplug68.c \
  libsc68/libsc68/emu68/mem68.c \
  libsc68/libsc68/emu68/getea68.c \
  libsc68/libsc68/emu68/inst68.c \
  libsc68/libsc68/emu68/emu68.c \
  libsc68/libsc68/emu68/error68.c \
  libsc68/desa68/desa68.c

OBJ = $(SRC:.c=.o)

libsc68.dylib: $(OBJ)
	$(CC) -dynamiclib -install_name $(INSTALLNAME) -o $@ $(OBJ)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) libsc68.dylib

.PHONY: clean
