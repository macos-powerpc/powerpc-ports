--- cmake/aws-c-io-config.cmake	2025-07-18 06:45:22.000000000 +0800
+++ cmake/aws-c-io-config.cmake	2025-08-18 20:18:39.000000000 +0800
@@ -1,6 +1,6 @@
 include(CMakeFindDependencyMacro)
 
-if (UNIX AND NOT APPLE AND NOT BYO_CRYPTO)
+if (UNIX AND NOT BYO_CRYPTO)
     find_dependency(s2n)
 endif()
 
