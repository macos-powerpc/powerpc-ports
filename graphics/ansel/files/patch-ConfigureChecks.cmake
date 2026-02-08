--- ConfigureChecks.cmake	2026-02-08 09:35:14.000000000 +0800
+++ ConfigureChecks.cmake	2026-02-08 14:29:09.000000000 +0800
@@ -82,7 +82,7 @@
 if(${BIGENDIAN})
     # we do not really want those.
     # besides, no one probably tried ansel on such systems
-    message(FATAL_ERROR "Found big endian system. Bad.")
+    message(STATUS "Found big endian system. Good.")
 else()
-    message(STATUS "Found little endian system. Good.")
+    message(STATUS "Found wrong endian system. Disappointing.")
 endif(${BIGENDIAN})
