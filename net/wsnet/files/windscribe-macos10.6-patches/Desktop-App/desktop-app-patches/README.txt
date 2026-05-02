Windscribe Desktop App Patches for Qt4 and MacPorts
===================================================

These patches enable building Windscribe Desktop App with:
- Qt4 instead of Qt5/Qt6
- MacPorts dependencies instead of vcpkg
- External wsnet library support
- macOS 10.6+ compatibility

PATCHES (apply in order):
=========================

0001-Add-Qt4-build-system-support.patch
  - Add Qt4 detection and configuration to CMake
  - Support QJson4 library for Qt4 builds
  - Conditional Qt version handling

0002-Update-QJson-includes-for-Qt4-compatibility.patch
  - Replace Qt5/Qt6 JSON includes with QJson4
  - Update JSON parsing code for Qt4 API

0003-Replace-QRegularExpression-with-QRegExp-for-Qt4.patch
  - Use QRegExp instead of QRegularExpression
  - Qt4 compatible regex handling

0004-Adapt-DPI-scaling-for-Qt4-compatibility.patch
  - Handle DPI scaling differences in Qt4
  - Remove Qt5+ specific scaling code

0005-Replace-QRandomGenerator-and-remove-QPermission-for-.patch
  - Use qrand() instead of QRandomGenerator
  - Remove QPermission (Qt6 only feature)

0006-Add-MacPorts-support-and-external-wsnet-detection.patch
  - Remove vcpkg integration for macOS
  - Use MacPorts OpenVPN and OpenSSL
  - Add find_package(wsnet) + FetchContent fallback
  - Auto-detect OpenVPN from standard paths

APPLICATION:
============

# Apply all patches to a fresh checkout
cd /path/to/Desktop-App
git am desktop-app-patches/0001-*.patch
git am desktop-app-patches/0002-*.patch
git am desktop-app-patches/0003-*.patch
git am desktop-app-patches/0004-*.patch
git am desktop-app-patches/0005-*.patch
git am desktop-app-patches/0006-*.patch

# Or apply as regular patches
for p in desktop-app-patches/000*.patch; do
  patch -p1 < "$p"
done

PREREQUISITES (MacPorts):
=========================

Required:
  sudo port install cmake ninja boost openssl openvpn spdlog qt4-mac

For wsnet (build separately or let FetchContent clone it):
  sudo port install c-ares curl rapidjson skyr-url

BUILD:
======

# Set compilers (for GCC on legacy macOS)
export CC=gcc-14
export CXX=g++-14
export MACOSX_DEPLOYMENT_TARGET=10.6

# Build
cd tools
./build_all.py --build-with-qt4 --build-app

NOTES:
======

- Qt4 GUI widgets are NOT fully ported - only build system and core/network
- CLI should be closer to working than GUI
- wsnet must be installed or will be fetched via git
- See ../wsnet/wsnet-patches/ for wsnet-specific patches
