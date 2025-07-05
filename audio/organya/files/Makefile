PREFIX   ?= /opt/local
CXX      ?= g++
CC       ?= gcc
CXXFLAGS += -Wall -fPIC -std=c++11
CFLAGS   += -Wall -fPIC

INSTALLDIR = $(DESTDIR)$(PREFIX)/lib
INSTALLNAME = $(PREFIX)/lib/liborganya.dylib

CPP_SRCS := \
  liborganya/organya/decoder.cpp \
  liborganya/organya/file.cpp \
  liborganya/pxtone/pxtnDelay.cpp \
  liborganya/pxtone/pxtnDescriptor.cpp \
  liborganya/pxtone/pxtnError.cpp \
  liborganya/pxtone/pxtnEvelist.cpp \
  liborganya/pxtone/pxtnMaster.cpp \
  liborganya/pxtone/pxtnMem.cpp \
  liborganya/pxtone/pxtnOverDrive.cpp \
  liborganya/pxtone/pxtnPulse_Frequency.cpp \
  liborganya/pxtone/pxtnPulse_Noise.cpp \
  liborganya/pxtone/pxtnPulse_NoiseBuilder.cpp \
  liborganya/pxtone/pxtnPulse_Oggv.cpp \
  liborganya/pxtone/pxtnPulse_Oscillator.cpp \
  liborganya/pxtone/pxtnPulse_PCM.cpp \
  liborganya/pxtone/pxtnService.cpp \
  liborganya/pxtone/pxtnService_moo.cpp \
  liborganya/pxtone/pxtnText.cpp \
  liborganya/pxtone/pxtnUnit.cpp \
  liborganya/pxtone/pxtnWoice.cpp \
  liborganya/pxtone/pxtnWoice_io.cpp \
  liborganya/pxtone/pxtnWoicePTV.cpp \
  liborganya/pxtone/pxtoneNoise.cpp

C_SRCS := \
  liborganya/organya/blip_buf.c

OBJS := $(CPP_SRCS:.cpp=.o) $(C_SRCS:.c=.o)

INCLUDES := -Iliborganya

TARGET := liborganya.dylib

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) -dynamiclib -o $@ $(OBJS) $(LDFLAGS) -install_name $(INSTALLNAME)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
