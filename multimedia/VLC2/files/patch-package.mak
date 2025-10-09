--- extras/package/macosx/package.mak.orig	2015-08-04 00:43:00.000000000 +0800
+++ extras/package/macosx/package.mak	2025-10-10 05:38:42.000000000 +0800
@@ -44,12 +44,12 @@
 	mkdir -p $(top_builddir)/tmp/modules/audio_output
 	mkdir -p $(top_builddir)/tmp/modules/gui/macosx
 	cd "$(srcdir)/modules/gui/macosx/" && cp *.h *.m $(abs_top_builddir)/tmp/modules/gui/macosx/
-	cd $(top_builddir)/tmp/extras/package/macosx && \
-		xcodebuild -target vlc SYMROOT=../../../build DSTROOT=../../../build $(silentstd)
+	mkdir -p $(top_builddir)/tmp/build/Default/VLC.bundle/Contents/MacOS
+	mkdir -p $(top_builddir)/tmp/build/Default/VLC.bundle/Contents/Resources
+	cp $(top_builddir)/tmp/extras/package/macosx/Info.plist $(top_builddir)/tmp/build/Default/VLC.bundle/Contents/
+	cp -R $(top_builddir)/tmp/extras/package/macosx/Resources/* $(top_builddir)/tmp/build/Default/VLC.bundle/Contents/Resources/
 	cp -R $(top_builddir)/tmp/build/Default/VLC.bundle $@
-	mkdir -p $@/Contents/Frameworks && cp -R $(CONTRIB_DIR)/Growl.framework $@/Contents/Frameworks/
 	mkdir -p $@/Contents/MacOS/share/locale/
-	cp -r "$(prefix)/lib/vlc/lua" "$(prefix)/share/vlc/lua" $@/Contents/MacOS/share/
 	mkdir -p $@/Contents/MacOS/include/
 	(cd "$(prefix)/include" && $(AMTAR) -c --exclude "plugins" vlc) | $(AMTAR) -x -C $@/Contents/MacOS/include/
 	$(INSTALL) -m 644 $(srcdir)/share/vlc512x512.png $@/Contents/MacOS/share/vlc512x512.png
