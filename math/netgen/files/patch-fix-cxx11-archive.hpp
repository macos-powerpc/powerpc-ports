--- libsrc/core/archive.hpp	2026-04-24 21:35:17.000000000 +0800
+++ libsrc/core/archive.hpp	2026-05-14 12:26:18.000000000 +0800
@@ -1167,7 +1167,7 @@
 
       // remove all \r characters from the string, check if size changed
       // if so, read the remaining characters
-      str.erase(std::remove(str.begin(), str.end(), '\r'), str.cend());
+      str.erase(std::remove(str.begin(), str.end(), '\r'), str.end());
       size_t chars_to_read = len-str.size();
       while (chars_to_read>0)
       {
@@ -1175,7 +1175,7 @@
         str.resize(len);
 
         stream->get(&str[old_size], chars_to_read+1, '\0');
-        str.erase(std::remove(str.begin()+old_size, str.end(), '\r'), str.cend());
+        str.erase(std::remove(str.begin()+old_size, str.end(), '\r'), str.end());
         chars_to_read = len - str.size();
       }
       return *this;
