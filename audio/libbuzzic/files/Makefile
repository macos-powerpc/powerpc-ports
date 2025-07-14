CC ?= gcc
CXX ?= g++
AR = ar rcs
CXXFLAGS += -std=c++17 -O2 -Wall
PREFIX ?= /usr/local
LIBDIR = $(PREFIX)/lib
INCLUDEDIR = $(PREFIX)/include/libbuzzic

SRCDIR = libbuzzic
SRC = $(wildcard $(SRCDIR)/*.c) $(wildcard $(SRCDIR)/*.cpp)
OBJ = $(SRC:.c=.o)
OBJ := $(OBJ:.cpp=.o)
HDR = $(wildcard $(SRCDIR)/*.h)

LIB = libbuzzic.a

all: $(LIB)

$(LIB): $(OBJ)
	$(AR) $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

install: $(LIB)
	install -d $(DESTDIR)$(LIBDIR)
	install -m 644 $(LIB) $(DESTDIR)$(LIBDIR)
	install -d $(DESTDIR)$(INCLUDEDIR)
	install -m 644 $(HDR) $(DESTDIR)$(INCLUDEDIR)

clean:
	rm -f $(SRCDIR)/*.o $(LIB)

.PHONY: all install clean
