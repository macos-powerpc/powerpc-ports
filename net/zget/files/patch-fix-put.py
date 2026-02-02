--- zget/put.py.orig	2016-12-04 23:32:52.000000000 +0800
+++ zget/put.py	2026-02-02 18:14:25.000000000 +0800
@@ -278,8 +278,11 @@
         infos.append(ServiceInfo(
             "_zget._http._tcp.local.",
             "%s._zget._http._tcp.local." % filehash,
-            socket.inet_aton(address), port, 0, 0,
-            {'path': None}
+            addresses=[socket.inet_aton(address)],
+            port=port,
+            weight=0,
+            priority=0,
+            properties={'path': None}
         ))
 
     try:
