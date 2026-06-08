--- autogen.sh	2025-02-14 18:36:41.000000000 +0800
+++ autogen.sh	2026-06-08 19:02:10.000000000 +0800
@@ -41,7 +41,7 @@
 
 ${ACLOCAL:-aclocal$AM_VERSION} ${ACLOCAL_ARG}
 ${AUTOHEADER:-autoheader$AC_VERSION} --force
-AUTOMAKE=$AUTOMAKE libtoolize -c --automake --force
+AUTOMAKE=$AUTOMAKE glibtoolize -c --automake --force
 $AUTOMAKE --add-missing --copy --include-deps
 ${AUTOCONF:-autoconf$AC_VERSION}
 
