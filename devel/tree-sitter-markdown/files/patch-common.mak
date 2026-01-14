--- common/common.mak	2026-01-11 18:44:35.000000000 +0800
+++ common/common.mak	2026-01-14 11:09:36.000000000 +0800
@@ -7,7 +7,7 @@
 TS ?= tree-sitter
 
 # install directory layout
-PREFIX ?= /usr/local
+PREFIX ?= @PREFIX@
 DATADIR ?= $(PREFIX)/share
 INCLUDEDIR ?= $(PREFIX)/include
 LIBDIR ?= $(PREFIX)/lib
@@ -34,7 +34,7 @@
 	SOEXT = dylib
 	SOEXTVER_MAJOR = $(SONAME_MAJOR).$(SOEXT)
 	SOEXTVER = $(SONAME_MAJOR).$(SONAME_MINOR).$(SOEXT)
-	LINKSHARED = -dynamiclib -Wl,-install_name,$(LIBDIR)/lib$(LANGUAGE_NAME).$(SOEXTVER),-rpath,@executable_path/../Frameworks
+	LINKSHARED = -dynamiclib -Wl,-install_name,$(LIBDIR)/lib$(LANGUAGE_NAME).$(SOEXT),-rpath,@executable_path/../Frameworks
 else ifneq ($(findstring mingw32,$(MACHINE)),)
 	SOEXT = dll
 	LINKSHARED += -s -shared -Wl,--out-implib,lib$(LANGUAGE_NAME).dll.a
