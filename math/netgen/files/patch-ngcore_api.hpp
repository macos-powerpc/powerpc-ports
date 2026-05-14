--- libsrc/core/ngcore_api.hpp	2026-04-24 21:35:17.000000000 +0800
+++ libsrc/core/ngcore_api.hpp	2026-05-14 11:49:22.000000000 +0800
@@ -98,8 +98,14 @@
 #define NETGEN_ARCH_ARM
 #endif
 
-#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
-#if __MAC_OS_X_VERSION_MIN_REQUIRED < 101400
+#if defined(__powerpc__) || defined(__POWERPC__)
+#define NETGEN_ARCH_PPC
+#endif
+
+#if defined(__APPLE__) && defined(__clang__)
+#include <AvailabilityMacros.h>
+
+#if MAC_OS_X_VERSION_MIN_REQUIRED < 101400
 // The c++ standard library on MacOS 10.13 and earlier has no aligned new operator,
 // thus implement it here globally
 #include <mm_malloc.h>
