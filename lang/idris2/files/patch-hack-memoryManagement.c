--- support/refc/memoryManagement.c	2025-11-01 01:11:29.000000000 +0800
+++ support/refc/memoryManagement.c	2025-11-02 14:20:14.000000000 +0800
@@ -43,7 +43,7 @@
 #endif
 
 Value *idris2_newValue(size_t size) {
-#if !defined(_WIN32) && defined(__STDC_VERSION__) &&                           \
+#if !defined(__APPLE__) && defined(__STDC_VERSION__) &&                           \
     (__STDC_VERSION__ >= 201112) /* C11 */
   Value *retVal = (Value *)aligned_alloc(
       sizeof(void *),
