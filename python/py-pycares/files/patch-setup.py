--- setup.py	2026-01-01 20:01:25.000000000 +0800
+++ setup.py	2026-01-18 10:30:03.000000000 +0800
@@ -63,10 +63,7 @@
         ]
 
         # Platform-specific configuration
-        if sys.platform == 'darwin':
-            # Set minimum macOS deployment target
-            cmake_args.append('-DCMAKE_OSX_DEPLOYMENT_TARGET=10.12')
-        elif sys.platform == 'win32':
+        if sys.platform == 'win32':
             # Windows-specific handling
             if 'mingw' in self.compiler.compiler_type:
                 cmake_args.extend(['-G', 'MinGW Makefiles'])
