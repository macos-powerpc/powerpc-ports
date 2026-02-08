--- src/osx/osx.mm	2026-02-08 14:26:24.000000000 +0800
+++ src/osx/osx.mm	2026-02-08 15:20:39.000000000 +0800
@@ -61,32 +61,34 @@
 
 float dt_osx_get_ppd()
 {
-  @autoreleasepool
+  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
+
+  NSScreen *nsscreen = [NSScreen mainScreen];
+  float result;
+  if ([nsscreen respondsToSelector: NSSelectorFromString(@"backingScaleFactor")])
   {
-    NSScreen *nsscreen = [NSScreen mainScreen];
-    if([nsscreen respondsToSelector: NSSelectorFromString(@"backingScaleFactor")])
-    {
-      return [[nsscreen valueForKey: @"backingScaleFactor"] floatValue];
-    }
-    else
-    {
-      return [[nsscreen valueForKey: @"userSpaceScaleFactor"] floatValue];
-    }
+    result = [[nsscreen valueForKey: @"backingScaleFactor"] floatValue];
+  }
+  else
+  {
+    result = [[nsscreen valueForKey: @"userSpaceScaleFactor"] floatValue];
   }
+
+  [pool drain];
+  return result;
 }
 
 static void dt_osx_disable_fullscreen(GtkWidget *widget)
 {
 #ifdef GDK_WINDOWING_QUARTZ
-  @autoreleasepool
-  {
+    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
     GdkWindow *window = gtk_widget_get_window(widget);
     if(window)
     {
       NSWindow *native = gdk_quartz_window_get_nswindow(window);
       [native setCollectionBehavior: ([native collectionBehavior] & ~NSWindowCollectionBehaviorFullScreenPrimary) | NSWindowCollectionBehaviorFullScreenAuxiliary];
     }
-  }
+    [pool drain];
 #endif
 }
 
@@ -102,26 +104,79 @@
 
 gboolean dt_osx_file_trash(const char *filename, GError **error)
 {
-  @autoreleasepool
-  {
-    NSFileManager *fm = [NSFileManager defaultManager];
-    NSError *err;
-
-    NSURL *url = [NSURL fileURLWithPath:@(filename)];
+  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
 
-    if ([fm respondsToSelector:@selector(trashItemAtURL:resultingItemURL:error:)]) {
-      if (![fm trashItemAtURL:url resultingItemURL:nil error:&err]) {
-        if (error != NULL)
-          *error = g_error_new_literal(G_IO_ERROR, err.code == NSFileNoSuchFileError ? G_IO_ERROR_NOT_FOUND : G_IO_ERROR_FAILED, err.localizedDescription.UTF8String);
-        return FALSE;
+  NSFileManager *fm = [NSFileManager defaultManager];
+  NSError *err = nil;
+  NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:filename]];
+  gboolean success = TRUE;
+
+  if ([fm respondsToSelector:@selector(trashItemAtURL:resultingItemURL:error:)]) {
+    if (![fm trashItemAtURL:url resultingItemURL:nil error:&err]) {
+      if (error != NULL) {
+        const char *msg = err.localizedDescription ? err.localizedDescription.UTF8String : "unknown error";
+        *error = g_error_new(
+          G_IO_ERROR,
+          err.code == NSFileNoSuchFileError ? G_IO_ERROR_NOT_FOUND : G_IO_ERROR_FAILED,
+          "%s",
+          msg
+        );
       }
-    } else {
+      success = FALSE;
+    }
+  } else {
+    /* fallback for <10.8 */
+    NSString *path = [url path];
+    if (![fm fileExistsAtPath:path]) {
       if (error != NULL)
-        *error = g_error_new_literal(G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED, "trash not supported on OS X versions < 10.8");
-      return FALSE;
+        *error = g_error_new(G_IO_ERROR, G_IO_ERROR_NOT_FOUND, "%s", "file not found");
+      success = FALSE;
+    } else {
+      NSString *trashDir = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];
+
+      if (![fm fileExistsAtPath:trashDir]) {
+        if (![fm createDirectoryAtPath:trashDir withIntermediateDirectories:YES attributes:nil error:&err]) {
+          if (error != NULL) {
+            const char *msg = err.localizedDescription ? err.localizedDescription.UTF8String : "unknown error";
+            *error = g_error_new(G_IO_ERROR, G_IO_ERROR_FAILED, "%s", msg);
+          }
+          success = FALSE;
+        }
+      }
+
+      if (success) {
+        NSString *destName = [path lastPathComponent];
+        NSString *destPath = [trashDir stringByAppendingPathComponent:destName];
+
+        /* make unique name if needed */
+        int suffix = 1;
+        while ([fm fileExistsAtPath:destPath]) {
+          NSString *base = [destName stringByDeletingPathExtension];
+          NSString *ext = [destName pathExtension];
+          NSString *candidate = ext.length ? [NSString stringWithFormat:@"%@-%d.%@", base, suffix, ext]
+                                           : [NSString stringWithFormat:@"%@-%d", base, suffix];
+          destPath = [trashDir stringByAppendingPathComponent:candidate];
+          suffix++;
+        }
+
+        if (![fm moveItemAtPath:path toPath:destPath error:&err]) {
+          if (error != NULL) {
+            const char *msg = err.localizedDescription ? err.localizedDescription.UTF8String : "unknown error";
+            *error = g_error_new(
+              G_IO_ERROR,
+              err.code == NSFileNoSuchFileError ? G_IO_ERROR_NOT_FOUND : G_IO_ERROR_FAILED,
+              "%s",
+              msg
+            );
+          }
+          success = FALSE;
+        }
+      }
     }
-    return TRUE;
   }
+
+  [pool drain];
+  return success;
 }
 
 char* dt_osx_get_bundle_res_path()
@@ -148,21 +203,23 @@
 
 static char* _get_user_locale()
 {
-  @autoreleasepool
+  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
+
+  NSLocale* locale_ns = [NSLocale currentLocale];
+  NSString* locale_c;
+  if([locale_ns respondsToSelector: @selector(languageCode)] && [locale_ns respondsToSelector: @selector(countryCode)])
   {
-    NSLocale* locale_ns = [NSLocale currentLocale];
-    NSString* locale_c;
-    if([locale_ns respondsToSelector: @selector(languageCode)] && [locale_ns respondsToSelector: @selector(countryCode)])
-    {
-      locale_c = [NSString stringWithFormat: @"%@_%@", [locale_ns languageCode], [locale_ns countryCode]];
-    }
-    else
-    {
-      // not ideal, but better than nothing
-      locale_c = [locale_ns localeIdentifier];
-    }
-    return strdup([locale_c UTF8String]);
+    locale_c = [NSString stringWithFormat: @"%@_%@", [locale_ns languageCode], [locale_ns countryCode]];
   }
+  else
+  {
+    // not ideal, but better than nothing
+    locale_c = [locale_ns localeIdentifier];
+  }
+
+  char *ret = strdup([locale_c UTF8String]);
+  [pool drain];
+  return ret;
 }
 
 static void _setup_ssl_trust(const char* const res_path)
