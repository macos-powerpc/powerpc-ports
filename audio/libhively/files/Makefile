CC ?= gcc
CFLAGS += -Wall -O2 -fPIC
LDFLAGS += -dynamiclib
SRCS = hvl_replay.c
OBJS = $(SRCS:.c=.o)
TARGET = libhively.dylib

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
