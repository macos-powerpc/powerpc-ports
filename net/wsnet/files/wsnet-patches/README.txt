WSNet Patches for macOS 10.6+ and GCC Compatibility
====================================================

These patches fix the following issues:

1. Fix curl finding to use pkgconfig instead of CMake config
   - Uses pkg_check_modules for curl on all platforms
   - Compatible with MacPorts-installed curl

2. Remove vcpkg dependency for macOS/Linux/Unix
   - Unix systems now use pkg-config for dependencies
   - vcpkg only used for Windows/Android/iOS
   - Compatible with MacPorts-provided dependencies

3. Make macOS code compatible with OS X 10.6+ and modern GCC
   - Added compatibility macros for older SDK
   - Handle CFAutorelease() not available on 10.6
   - ARC compilation only enabled for Clang, not GCC

4. Remove OSX deployment target setting
   - Allows MacPorts build system to control deployment target

5. Add proper install target for desktop platforms
   - Creates wsnet-config.cmake for find_package() support
   - Installs library, headers, and CMake config files
   - Compatible with Windscribe Desktop-App

FILES:
======

wsnet-macos-compat.patch
  Modifies:
  - CMakeLists.txt (pkg-config, vcpkg removal, ARC handling)
  - src/pingmanager/apple/pingmanager_apple.mm (10.6 compat)
  - src/pingmanager/apple/simple_ping.h (10.6 compat)
  - src/pingmanager/apple/simple_ping.mm (10.6 compat)

skyr-url-gcc-fix.patch
  This is an UPSTREAM patch for skyr-url library (cpp-netlib/url)
  Fixes GCC compilation error with const_iterator in erase()
  Apply to skyr-url sources before building:
    cd /path/to/skyr-url
    patch -p1 < skyr-url-gcc-fix.patch

  Fixes: https://github.com/Windscribe/wsnet/issues/7

APPLICATION ORDER:
==================

1. First patch skyr-url (if building from source):
   cd /path/to/skyr-url
   patch -p1 < skyr-url-gcc-fix.patch

2. Then apply wsnet patches:
   cd /path/to/wsnet
   patch -p1 < wsnet-patches/wsnet-macos-compat.patch

3. Build and install wsnet:
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release
   cmake --build .
   sudo cmake --install .

PREREQUISITES (MacPorts):
=========================

Required packages:
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
