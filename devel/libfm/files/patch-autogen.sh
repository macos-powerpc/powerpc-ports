--- autogen.sh	2025-12-14 20:34:56.000000000 +0800
+++ autogen.sh	2026-06-08 19:11:01.000000000 +0800
@@ -42,7 +42,7 @@
 gtkdocize --copy
 ${ACLOCAL:-aclocal$AM_VERSION} ${ACLOCAL_ARG}
 ${AUTOHEADER:-autoheader$AC_VERSION} --force
-AUTOMAKE=$AUTOMAKE libtoolize -c --automake --force
+AUTOMAKE=$AUTOMAKE glibtoolize -c --automake --force
 AUTOMAKE=$AUTOMAKE intltoolize -c --automake --force
 $AUTOMAKE --add-missing --copy --include-deps
 ${AUTOCONF:-autoconf$AC_VERSION}
