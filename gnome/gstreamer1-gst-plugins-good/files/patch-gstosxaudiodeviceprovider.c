--- sys/osxaudio/gstosxaudiodeviceprovider.c	2026-04-08 03:02:23.000000000 +0800
+++ sys/osxaudio/gstosxaudiodeviceprovider.c	2026-05-06 23:44:05.000000000 +0800
@@ -230,7 +230,7 @@
 }
 
 static AudioObjectPropertyAddress
-_get_devices_list_address ()
+_get_devices_list_address (void)
 {
   AudioObjectPropertyAddress address = {
     .mSelector = kAudioHardwarePropertyDevices,
