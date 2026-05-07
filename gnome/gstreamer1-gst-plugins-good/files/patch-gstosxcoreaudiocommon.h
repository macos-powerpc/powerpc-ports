--- sys/osxaudio/gstosxcoreaudiocommon.h	2026-04-08 03:02:23.000000000 +0800
+++ sys/osxaudio/gstosxcoreaudiocommon.h	2026-05-07 06:38:46.000000000 +0800
@@ -26,6 +26,51 @@
 #include "gstosxcoreaudio.h"
 #include <gst/audio/audio-channels.h>
 
+#include <AvailabilityMacros.h>
+
+#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070
+# define kAudioChannelLabel_RearSurroundLeft      33
+# define kAudioChannelLabel_RearSurroundRight     34
+# define kAudioChannelLabel_LeftWide              35
+# define kAudioChannelLabel_RightWide             36
+# define kAudioChannelLabel_LFE2                  37
+# define kAudioChannelLabel_LeftTotal             38
+# define kAudioChannelLabel_RightTotal            39
+# define kAudioChannelLabel_HearingImpaired       40
+# define kAudioChannelLabel_Narration             41
+# define kAudioChannelLabel_Mono                  42
+# define kAudioChannelLabel_DialogCentricMix      43
+# define kAudioChannelLabel_CenterSurroundDirect  44
+# define kAudioChannelLabel_Haptic                45
+# define kAudioChannelLabel_Discrete              400
+#endif
+
+#ifndef kAudioDevicePropertyIsHidden
+# define kAudioDevicePropertyIsHidden 'hidn'
+#endif
+
+#ifndef kAudioDeviceTransportTypeUnknown
+# define kAudioDeviceTransportTypeUnknown 0
+#endif
+
+#ifndef kAudioObjectPropertyElementMain
+# define kAudioObjectPropertyElementMain kAudioObjectPropertyElementMaster
+#endif
+
+#ifndef kAudioTimeStampSampleHostTimeValid
+# define kAudioTimeStampSampleHostTimeValid \
+    (kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid)
+#endif
+
+#ifndef __AudioTimeStampFlags__
+typedef UInt32 AudioTimeStampFlags;
+#endif
+
+/* __nullable is a Clang nullability annotation; GCC does not define it */
+#ifndef __nullable
+# define __nullable
+#endif
+
 G_BEGIN_DECLS
 
 typedef struct
