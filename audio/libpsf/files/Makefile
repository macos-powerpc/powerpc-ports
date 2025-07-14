PREFIX ?= /opt/local
CC ?= gcc
CFLAGS += -fPIC -Ilibpsf
LDFLAGS += -dynamiclib -lz
INSTALLDIR = $(DESTDIR)$(PREFIX)/lib
INSTALLNAME = $(PREFIX)/lib/libpsf.dylib
TARGET = libpsf.dylib

SRCS = \
	libpsf/ao.c \
	libpsf/corlett.c \
	libpsf/eng_dsf/eng_dsf.c \
	libpsf/eng_dsf/dc_hw.c \
	libpsf/eng_dsf/aica.c \
	libpsf/eng_dsf/aicadsp.c \
	libpsf/eng_dsf/arm7.c \
	libpsf/eng_dsf/arm7i.c \
	libpsf/eng_ssf/m68kcpu.c \
	libpsf/eng_ssf/m68kopac.c \
	libpsf/eng_ssf/m68kopdm.c \
	libpsf/eng_ssf/m68kopnz.c \
	libpsf/eng_ssf/m68kops.c \
	libpsf/eng_ssf/scsp.c \
	libpsf/eng_ssf/scspdsp.c \
	libpsf/eng_ssf/sat_hw.c \
	libpsf/eng_ssf/eng_ssf.c \
	libpsf/eng_qsf/eng_qsf.c \
	libpsf/eng_qsf/kabuki.c \
	libpsf/eng_qsf/qsound.c \
	libpsf/eng_qsf/z80.c \
	libpsf/eng_qsf/z80dasm.c \
	libpsf/eng_psf/eng_psf.c \
	libpsf/eng_psf/psx.c \
	libpsf/eng_psf/psx_hw.c \
	libpsf/eng_psf/peops/spu.c \
	libpsf/eng_psf/eng_psf2.c \
	libpsf/eng_psf/peops2/spu2.c \
	libpsf/eng_psf/peops2/dma2.c \
	libpsf/eng_psf/peops2/registers2.c \
	libpsf/eng_psf/eng_spu.c

OBJS = $(SRCS:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -install_name $(INSTALLNAME) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)
