# Ultimate++ 2026.1 macOS 10.6 SDK / GCC 14 / PowerPC Patches

This patch set enables building Ultimate++ on macOS 10.6 SDK with GCC 14 targeting PowerPC architecture.

## Key Changes

### 1. GCC ObjC Runtime Compatibility (Critical)
GCC's ObjC runtime cannot handle C++ objects stored directly in ObjC instance variables.
This causes crashes when NSWindow/NSView subclasses store C++ pointers as ivars.

**Solution**: Use `objc_setAssociatedObject`/`objc_getAssociatedObject` to store data
without ivars. CocoWindow and CocoView are now typedef'd to NSWindow/NSView with
helper functions to get/set the associated Ctrl* and active flag.

### 2. NSWindow Method Swizzling
Instead of subclassing NSWindow (which crashes with GCC), we swizzle
`canBecomeKeyWindow` and `canBecomeMainWindow` at runtime to provide U++ behavior.

### 3. Menu Action Dispatch
Menu item actions are routed through AppDelegate's `cocoMenuAction:` method,
which then looks up the associated CocoMenuBar and dispatches the callback.

### 4. macOS 10.6 SDK Compatibility
- Use explicit NSRect/NSSize constructors (NSMakeRect, NSMakeSize) instead of implicit CGRect casts
- Use NSUInteger instead of NSWindowStyleMask (10.12+ typedef)
- Use graphicsPort instead of CGContext property (10.6-10.9)
- Use bracket syntax [obj isKeyWindow] instead of dot syntax obj.keyWindow
- Avoid blocks in favor of CGEventTap for event monitoring

### 5. Lambda Fixes for GCC 14 PowerPC
- Fix ICE (Internal Compiler Error) in JSON.h and Xmlize.h by using primary templates
  instead of partial specialization with lambdas

### 6. BMP Endian Fix
- Fix byte swapping macros for big-endian (PowerPC) systems

## Files Modified

### CtrlCore
- `CocoApp.mm` - AppDelegate menu handler, CGEventTap for GCC
- `CocoMM.h` - Associated object helpers, typedef for CocoWindow/CocoView
- `CocoDraw.mm` - graphicsPort for 10.6
- `CocoDrawOp.mm` - NSRect conversions
- `CocoProc.mm` - Associated object keys, logging
- `CocoWin.mm` - Method swizzling, NSRect/NSSize conversions
- `CocoClip.mm` - NSRect conversions
- `CocoImage.mm` - NSRect conversions

### CtrlLib
- `MacMenu.mm` - Use AppDelegate as menu target
- `ChCocoMM.mm` - NSRect/NSSize conversions
- `Cocoa.mm` - NSRect conversions

### Draw
- `FontCoco.mm` - graphicsPort for 10.6

### plugin/bmp
- `bmphdr.h` - Big-endian byte swapping

### Core
- `JSON.h` - Lambda fix for GCC 14 PowerPC ICE
- `Xmlize.h` - Lambda fix for GCC 14 PowerPC ICE

## Application

Apply patches from the root of the U++ source tree:

```bash
cd ultimatepp
for p in patches_2026/patches/*.diff; do
    patch -p1 < "$p"
done
```

Or copy the pre-patched source files:

```bash
cp -r patches_2026/uppsrc/* uppsrc/
```

## Known Issues

- Modal dialogs may have focus/keyboard input issues still being investigated
- Debug logging (NSLog) is currently enabled for troubleshooting

## Date
2026-05-03
