--- include/args.h	2025-10-31 10:40:01.000000000 +0800
+++ include/args.h	2025-11-02 16:40:46.000000000 +0800
@@ -80,17 +80,25 @@
     size_t max_descr_len;
 } Args;
 
-#if defined(__has_attribute) && __has_attribute(unused)
+#if defined(__has_attribute)
+#if __has_attribute(unused)
 #define ARGS__MAYBE_UNUSED __attribute__((unused))
 #else
 #define ARGS__MAYBE_UNUSED
 #endif
+#else
+#define ARGS__MAYBE_UNUSED
+#endif
 
-#if defined(__has_attribute) && __has_attribute(warn_unused_result)
+#if defined(__has_attribute)
+#if __has_attribute(warn_unused_result)
 #define ARGS__WARN_UNUSED_RESULT __attribute__((warn_unused_result))
 #else
 #define ARGS__WARN_UNUSED_RESULT
 #endif
+#else
+#define ARGS__WARN_UNUSED_RESULT
+#endif
 
 #define ARGS__FATAL(...)              \
     do {                              \
