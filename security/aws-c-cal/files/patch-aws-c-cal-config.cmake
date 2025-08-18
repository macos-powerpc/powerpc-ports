--- cmake/aws-c-cal-config.cmake	2025-06-04 06:03:34.000000000 +0800
+++ cmake/aws-c-cal-config.cmake	2025-08-18 20:22:31.000000000 +0800
@@ -2,7 +2,7 @@
 
 find_dependency(aws-c-common)
 
-if (NOT @BYO_CRYPTO@ AND (@AWS_USE_LIBCRYPTO_TO_SUPPORT_ED25519_EVERYWHERE@ OR (NOT WIN32 AND NOT APPLE)))
+if (NOT @BYO_CRYPTO@ AND (@AWS_USE_LIBCRYPTO_TO_SUPPORT_ED25519_EVERYWHERE@ OR NOT WIN32))
     if (@USE_OPENSSL@ AND NOT ANDROID)
         # aws-c-cal has been built with a dependency on OpenSSL::Crypto,
         # therefore consumers of this library have a dependency on OpenSSL and must have it found
