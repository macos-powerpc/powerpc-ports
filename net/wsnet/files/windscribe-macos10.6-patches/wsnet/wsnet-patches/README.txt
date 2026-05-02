WSNet Patches for macOS 10.6+ and GCC Compatibility
====================================================

These patches enable building wsnet with:
- macOS 10.6+ SDK compatibility
- GCC (gcc-14) instead of Clang
- MacPorts dependencies instead of vcpkg
- Proper CMake install targets

PATCHES:
========

0001-Add-macOS-10.6-compatibility-GCC-support-and-install.patch
  Main wsnet patch:
  - Remove vcpkg dependency for Unix systems, use pkg-config
  - Add macOS 10.6 SDK compatibility macros for simple_ping
  - Handle CFAutorelease not available on 10.6
  - Only enable ARC with Clang, not GCC
  - Add CMake install targets with config files
  - Support find_package(wsnet CONFIG) for Desktop-App

skyr-url-gcc-fix.patch
  UPSTREAM patch for skyr-url library (cpp-netlib/url):
  - Fix GCC compilation error with const_iterator in erase()
  - Must be applied to skyr-url sources before building
  - Fixes: https://github.com/Windscribe/wsnet/issues/7

APPLICATION:
============

# 1. First patch skyr-url (if building from source)
cd /path/to/skyr-url
patch -p1 < skyr-url-gcc-fix.patch
cmake -B build && cmake --build build && sudo cmake --install build

# 2. Apply wsnet patch
cd /path/to/wsnet
git am wsnet-patches/0001-*.patch
# Or: patch -p1 < wsnet-patches/0001-*.patch

# 3. Build and install wsnet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
sudo cmake --install .

PREREQUISITES (MacPorts):
=========================

Required:
  sudo port install cmake ninja boost openssl spdlog \
                    rapidjson skyr-url c-ares curl

BUILD:
======

export CC=gcc-14
export CXX=g++-14
export MACOSX_DEPLOYMENT_TARGET=10.6

mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
sudo cmake --install .

INSTALL LOCATIONS:
==================

After install, wsnet provides:
  - Library: ${CMAKE_INSTALL_LIBDIR}/libwsnet.so (or .dylib)
  - Headers: ${CMAKE_INSTALL_INCLUDEDIR}/wsnet/
  - CMake config: ${CMAKE_INSTALL_LIBDIR}/cmake/wsnet/

Desktop-App can then find wsnet via:
  find_package(wsnet CONFIG REQUIRED)
  target_link_libraries(myapp PRIVATE wsnet::wsnet)
