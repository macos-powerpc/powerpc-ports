PREFIX ?= /opt/local
CC ?= gcc
CFLAGS += -Wall -fPIC
LDFLAGS += -dynamiclib
SRCS = hvl_replay.c
OBJS = $(SRCS:.c=.o)
INSTALLDIR = $(DESTDIR)$(PREFIX)/lib
INSTALLNAME = $(PREFIX)/lib/libhively.dylib
TARGET = libhively.dylib

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -install_name $(INSTALLNAME) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
