--- sys/osxaudio/gstosxcoreaudiohal.c	2026-04-08 03:02:23.000000000 +0800
+++ sys/osxaudio/gstosxcoreaudiohal.c	2026-05-06 23:41:54.000000000 +0800
@@ -171,9 +171,11 @@
   OSStatus status = noErr;
   UInt32 hidden = FALSE;
   UInt32 property_size = sizeof (hidden);
-  AudioObjectPropertyAddress property_address;
+  AudioObjectPropertyAddress property_address = { 0 };  /* zero all fields */
 
   property_address.mSelector = kAudioDevicePropertyIsHidden;
+  property_address.mScope = kAudioObjectPropertyScopeGlobal;
+  property_address.mElement = kAudioObjectPropertyElementMain;
 
   status = AudioObjectGetPropertyData (device_id,
       &property_address, 0, NULL, &property_size, &hidden);
