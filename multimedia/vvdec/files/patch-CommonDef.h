--- source/Lib/CommonLib/CommonDef.h	2025-11-18 19:22:17.000000000 +0800
+++ source/Lib/CommonLib/CommonDef.h	2026-02-18 20:56:31.000000000 +0800
@@ -68,6 +68,10 @@
 # define REAL_TARGET_LOONGARCH 1
 #endif
 
+#ifdef __APPLE__
+# include <AvailabilityMacros.h>
+#endif
+
 #ifdef _WIN32
 #  include <intrin.h>
 #endif
@@ -441,7 +445,11 @@
 #define MEMORY_ALIGN_DEF_SIZE       32  // for use with avx2 (256 bit)
 #define CACHE_MEM_ALIGN_SIZE      1024
 
-#define ALIGNED_MALLOC              1   ///< use 32-byte aligned malloc/free
+#if !defined(__APPLE__) || MAC_OS_X_VERSION_MIN_REQUIRED >= 1060 // Yes, here we do not want legacy-support.
+# define ALIGNED_MALLOC              1   ///< use 32-byte aligned malloc/free
+#else
+# define ALIGNED_MALLOC              0 
+#endif
 
 #if ALIGNED_MALLOC
 
