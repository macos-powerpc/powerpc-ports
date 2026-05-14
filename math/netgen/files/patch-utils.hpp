--- libsrc/core/utils.hpp	2026-04-24 21:35:17.000000000 +0800
+++ libsrc/core/utils.hpp	2026-05-14 12:06:51.000000000 +0800
@@ -12,7 +12,7 @@
 
 #include "ngcore_api.hpp"       // for NGCORE_API and CPU arch macros
 
-#if defined(__APPLE__) && defined(NETGEN_ARCH_ARM64)
+#if defined(__APPLE__)
 #include <mach/mach_time.h>
 #endif
 
@@ -69,6 +69,8 @@
     unsigned long long tics;
     __asm __volatile("mrs %0, CNTVCT_EL0" : "=&r" (tics));
     return tics;
+#elif defined(__APPLE__) && defined(NETGEN_ARCH_PPC)
+    return mach_absolute_time();
 #elif defined(__EMSCRIPTEN__) || (defined(_MSC_VER) && defined(_M_ARM64))
     return std::chrono::high_resolution_clock::now().time_since_epoch().count();
 #else
