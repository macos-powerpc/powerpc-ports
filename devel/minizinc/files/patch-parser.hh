--- include/minizinc/parser.hh.orig	2025-09-29 07:04:56.000000000 +0800
+++ include/minizinc/parser.hh	2026-01-03 12:02:03.000000000 +0800
@@ -59,6 +59,10 @@
 #include <locale.h>  // newlocale, freelocale
 #endif
 
+#ifdef __APPLE__
+#include <xlocale.h>
+#endif
+
 namespace MiniZinc {
 
 struct ParseWorkItem {
