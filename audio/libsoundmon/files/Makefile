PREFIX ?= /opt/local
CC ?= gcc
CXX ?= g++
CFLAGS += -Wall -fPIC
CXXFLAGS += -std=c++11 -Wall -fPIC
LDFLAGS += -dynamiclib
INSTALLDIR = $(DESTDIR)$(PREFIX)/lib
INSTALLNAME = $(PREFIX)/lib/libsoundmon.dylib
TARGET = libsoundmon.dylib

C_SRCS := $(wildcard libsoundmon/*.c)
CPP_SRCS := $(wildcard libsoundmon/*.cpp)
OBJS := $(C_SRCS:.c=.o) $(CPP_SRCS:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(LDFLAGS) -install_name $(INSTALLNAME) -o $@ $(OBJS)

libsoundmon/%.o: libsoundmon/%.c
	$(CC) $(CFLAGS) -c $< -o $@

libsoundmon/%.o: libsoundmon/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f libsoundmon/*.o $(TARGET)

.PHONY: all clean
