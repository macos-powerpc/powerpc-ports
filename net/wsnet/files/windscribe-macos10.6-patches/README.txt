Windscribe VPN - macOS 10.6+ / Qt4 / MacPorts Patches
=====================================================

This directory contains patches and modifications for building
Windscribe VPN client on legacy macOS (10.6+) with:
- Qt4 instead of Qt5/Qt6
- GCC instead of Clang
- MacPorts dependencies instead of vcpkg

CONTENTS:
=========

wsnet/
  Windscribe networking library
  - wsnet-patches/  - Patches for 10.6 compat, GCC, install targets
  - Committed changes on top of upstream

Desktop-App/
  Windscribe Desktop VPN client
  - desktop-app-patches/  - Qt4 and MacPorts patches
  - Committed changes on branch qt4-port-clean

PATCH_SUMMARY.txt
  Overview of all patches

BUILD ORDER:
============

1. Patch and build skyr-url (dependency):
   cd /path/to/skyr-url
   patch -p1 < wsnet/wsnet-patches/skyr-url-gcc-fix.patch
   cmake -B build && cmake --build build && sudo cmake --install build

2. Build and install wsnet:
   cd wsnet
   # Patches already applied (committed)
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release
   cmake --build .
   sudo cmake --install .

3. Build Desktop-App:
   cd Desktop-App
   # Patches already applied (committed)
   cd tools
   ./build_all.py --build-with-qt4 --build-app

PREREQUISITES (MacPorts):
=========================

sudo port install cmake ninja boost openssl openvpn spdlog \
                  rapidjson skyr-url c-ares curl qt4-mac gcc14

CURRENT STATUS:
===============

wsnet library:
  [x] macOS 10.6 compatibility
  [x] GCC support (no ARC)
  [x] pkg-config instead of vcpkg
  [x] CMake install targets
  [x] skyr-url GCC fix (upstream patch)

Desktop-App:
  [x] Qt4 build system support
  [x] Qt4 Core/Network compatibility
  [x] MacPorts OpenVPN/OpenSSL support
  [x] External wsnet detection
  [ ] Qt4 GUI widget porting (NOT DONE)
  [ ] Full CLI testing
  [ ] Helper process testing

NOTES:
======

- CLI should be closer to working than GUI
- GUI requires extensive Qt4 widget porting not yet done
- Only build system and Core/Network code adapted for Qt4
