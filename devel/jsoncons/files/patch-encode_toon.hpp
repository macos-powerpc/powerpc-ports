--- include/jsoncons_ext/toon/encode_toon.hpp.orig	2026-08-08 00:09:35.000000000 +0800
+++ include/jsoncons_ext/toon/encode_toon.hpp	2026-08-09 02:01:17.000000000 +0800
@@ -117,7 +117,7 @@
         }
     }
 
-    std::size_t exponent;
+    std::size_t exponent = 0;
     dec_to_integer(exponent_str.data(), exponent_str.size(), exponent);
 
     std::size_t n = num_str.size();
