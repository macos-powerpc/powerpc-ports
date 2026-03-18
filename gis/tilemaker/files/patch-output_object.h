--- include/output_object.h	2026-03-18 08:39:17.000000000 +0800
+++ include/output_object.h	2026-03-19 06:23:25.000000000 +0800
@@ -27,7 +27,7 @@
 		uint_least8_t l,
 		NodeID id,
 		AttributeIndex attributes,
-		uint mz
+		unsigned int mz
 	):
 		objectID(id),
 		geomType(type),
