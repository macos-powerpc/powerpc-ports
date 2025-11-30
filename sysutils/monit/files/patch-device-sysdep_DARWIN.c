--- src/device/sysdep_DARWIN.c	2025-05-08 15:51:11.000000000 +0800
+++ src/device/sysdep_DARWIN.c	2025-11-30 07:24:26.000000000 +0800
@@ -54,6 +54,8 @@
 #include <sys/mount.h>
 #endif
 
+#include <AvailabilityMacros.h>
+
 #ifdef HAVE_DISKARBITRATION_DISKARBITRATION_H
 #include <DiskArbitration/DiskArbitration.h>
 #endif
@@ -100,6 +102,7 @@
         DASessionRef session = DASessionCreate(NULL);
         if (session) {
                 CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)inf->filesystem->object.mountpoint, strlen(inf->filesystem->object.mountpoint), true);
+#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
                 DADiskRef disk = DADiskCreateFromVolumePath(NULL, session, url);
                 if (disk) {
                         DADiskRef wholeDisk = DADiskCopyWholeDisk(disk);
@@ -156,6 +159,7 @@
                         }
                         CFRelease(disk);
                 }
+#endif
                 CFRelease(url);
                 CFRelease(session);
         }
