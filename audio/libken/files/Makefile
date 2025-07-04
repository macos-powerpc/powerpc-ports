CXX ?= g++
CXXFLAGS += -Wall -std=c++11 -fPIC
LDFLAGS += -dynamiclib
SRCS = adlib.cpp kdmdecoder.cpp ksmdecoder.cpp smdecoder.cpp
OBJS = $(SRCS:.c=.o)
TARGET = libken.dylib

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
