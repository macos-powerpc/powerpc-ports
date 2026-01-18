--- pywidevine/device.py	2023-12-22 19:12:52.000000000 +0800
+++ pywidevine/device.py	2026-01-18 11:23:34.000000000 +0800
@@ -33,7 +33,7 @@
     # - Removed vmp and vmp_len as it should already be within the Client ID
     v2 = Struct(
         "signature" / magic,
-        "version" / Const(Int8ub, 2),
+        "version" / Const(2, Int8ub),
         "type_" / CEnum(
             Int8ub,
             **{t.name: t.value for t in DeviceTypes}
@@ -52,7 +52,7 @@
     # - Removed system_id as it can be retrieved from the Client ID's DRM Certificate
     v1 = Struct(
         "signature" / magic,
-        "version" / Const(Int8ub, 1),
+        "version" / Const(1, Int8ub),
         "type_" / CEnum(
             Int8ub,
             **{t.name: t.value for t in DeviceTypes}
