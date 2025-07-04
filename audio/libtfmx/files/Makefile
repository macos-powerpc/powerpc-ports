CC ?= gcc
CXX ?= g++
CFLAGS += -std=gnu11 -fPIC
CXXFLAGS += -std=gnu++11 -fPIC
LDFLAGS += -dynamiclib
TARGET = libtfmx.dylib

SRC_C = $(wildcard libtfmx/*.c)
SRC_CPP = $(wildcard libtfmx/*.cpp)
OBJS = $(SRC_C:.c=.o) $(SRC_CPP:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(LDFLAGS) -o $@ $(OBJS)

libtfmx/%.o: libtfmx/%.c
	$(CC) $(CFLAGS) -c $< -o $@

libtfmx/%.o: libtfmx/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f libtfmx/*.o $(TARGET)
