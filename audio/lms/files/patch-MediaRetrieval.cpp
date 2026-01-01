--- src/libs/subsonic/impl/endpoints/MediaRetrieval.cpp
+++ src/libs/subsonic/impl/endpoints/MediaRetrieval.cpp	2026-01-01 13:09:08.000000000 +0800
@@ -56,7 +56,7 @@
             core::media::Container container;
             core::media::Codec codec;
         };
-        constexpr std::array outputFormats{
+        const std::array outputFormats{
             OutputFormat{ "mp3", core::media::Container::MPEG, core::media::Codec::MP3 },
             OutputFormat{ "opus", core::media::Container::Ogg, core::media::Codec::Opus },
             OutputFormat{ "vorbis", core::media::Container::Ogg, core::media::Codec::Vorbis },
