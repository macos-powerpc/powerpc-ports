--- openEMS.sh.orig	2026-01-23 01:46:54.000000000 +0800
+++ openEMS.sh	2026-02-27 16:23:25.000000000 +0800
@@ -1,7 +1,11 @@
 #!/bin/sh
 
-#clear LD_LIBRARY_PATH
-export LD_LIBRARY_PATH=
+if [ -n "$DYLD_LIBRARY_PATH" ]; then
+   DYLD_LIBRARY_PATH=/opt/local/lib/libgcc:${DYLD_LIBRARY_PATH}
+else
+   DYLD_LIBRARY_PATH=/opt/local/lib/libgcc
+fi
+export DYLD_LIBRARY_PATH
 
 #get path to openEMS
 openEMS_PATH=`dirname $0`
