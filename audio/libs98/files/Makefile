PREFIX   ?= /opt/local
CXX      ?= g++
CC       ?= gcc
AR        = ar
CFLAGS   += -fPIC -Ilibs98 @extra_flag@
CXXFLAGS += -fPIC -Ilibs98
LDFLAGS   = -dynamiclib -lz
LIBNAME   = libs98.dylib
INSTALLDIR = $(DESTDIR)$(PREFIX)/lib
INSTALLNAME = $(PREFIX)/lib/$(LIBNAME)

C_SOURCES = \
  libs98/device/emu2413/emu2413.c \
  libs98/device/mame/fmopl.c \
  libs98/device/mame/ymf262.c \
  libs98/device/s_logtbl.c \
  libs98/device/s_sng.c

CPP_SOURCES = \
  libs98/s98.cpp \
  libs98/device/fmgen/file.cpp \
  libs98/device/fmgen/fmgen.cpp \
  libs98/device/fmgen/fmtimer.cpp \
  libs98/device/fmgen/opm.cpp \
  libs98/device/fmgen/opna.cpp \
  libs98/device/fmgen/psg.cpp \
  libs98/device/s98mame.cpp \
  libs98/device/s98fmgen.cpp \
  libs98/device/s98opll.cpp \
  libs98/device/s98sng.cpp

OBJS = $(C_SOURCES:.c=.o) $(CPP_SOURCES:.cpp=.o)

all: $(LIBNAME)

$(LIBNAME): $(OBJS)
	$(CXX) $(LDFLAGS) -install_name $(INSTALLNAME) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(LIBNAME)

.PHONY: all clean
