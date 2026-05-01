// SPDX-FileCopyrightText: Copyright (c) Ken Martin, Will Schroeder, Bill Lorensen
// SPDX-License-Identifier: BSD-3-Clause
/**
 * @class   vtkCocoaMacOSXSDKCompatibility
 * @brief   Compatibility header
 *
 * VTK requires the Mac OS X 10.5 SDK or later.
 * However, this file is meant to allow us to use features from newer
 * SDKs by adding workarounds to still support the minimum SDK.
 * It is safe to include this header multiple times.
 */

#include <AvailabilityMacros.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
#error VTK requires the Mac OS X 10.5 SDK or later
#endif

#if MAC_OS_X_VERSION_MIN_REQUIRED < 1050
#error VTK requires a deployment target of Mac OS X 10.5 or later
#endif

// Provide __has_feature for compilers that don't support it (e.g. gcc)
#ifndef __has_feature
#define __has_feature(x) 0
#endif

// Portable diagnostic push/pop/ignore macros for gcc and clang
#ifdef __clang__
#define VTK_DIAG_STR(s) #s
#define VTK_DIAG_JOINSTR(x,y) VTK_DIAG_STR(x ## y)
#define VTK_DIAG_DO_PRAGMA(x) _Pragma(#x)
#define VTK_DIAG_PRAGMA(x) VTK_DIAG_DO_PRAGMA(clang diagnostic x)
#define VTK_DIAG_OFF(x) \
  VTK_DIAG_PRAGMA(push) \
  VTK_DIAG_PRAGMA(ignored VTK_DIAG_JOINSTR(-W,x))
#define VTK_DIAG_ON(x) VTK_DIAG_PRAGMA(pop)
#elif defined(__GNUC__)
#define VTK_DIAG_STR(s) #s
#define VTK_DIAG_JOINSTR(x,y) VTK_DIAG_STR(x ## y)
#define VTK_DIAG_DO_PRAGMA(x) _Pragma(#x)
#define VTK_DIAG_PRAGMA(x) VTK_DIAG_DO_PRAGMA(GCC diagnostic x)
#if (__GNUC__ > 4) || ((__GNUC__ == 4) && (__GNUC_MINOR__ >= 6))
#define VTK_DIAG_OFF(x) \
  VTK_DIAG_PRAGMA(push) \
  VTK_DIAG_PRAGMA(ignored VTK_DIAG_JOINSTR(-W,x))
#define VTK_DIAG_ON(x) VTK_DIAG_PRAGMA(pop)
#else
#define VTK_DIAG_OFF(x) VTK_DIAG_PRAGMA(ignored VTK_DIAG_JOINSTR(-W,x))
#define VTK_DIAG_ON(x) VTK_DIAG_PRAGMA(warning VTK_DIAG_JOINSTR(-W,x))
#endif
#else
#define VTK_DIAG_OFF(x)
#define VTK_DIAG_ON(x)
#endif

// Stop AssertMacros.h from defining its macros without underscore prefixes,
// which pollute the global namespace and cause us build issues.
// This is default as of the macOS 10.13 SDK, but needed for older SDKs.
#if MAC_OS_X_VERSION_MAX_ALLOWED < 101300
#define __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES 0
#endif

#if (MAC_OS_X_VERSION_MAX_ALLOWED < 101200) && !defined(VTK_DONT_MAP_10_12_ENUMS)
// The 10.12 SDK made a bunch of enum names more logical, map old names to new names to continue
// supporting old SDKs.
#define NSWindowStyleMask NSUInteger
#define NSWindowStyleMaskBorderless NSBorderlessWindowMask
#define NSWindowStyleMaskTitled NSTitledWindowMask
#define NSWindowStyleMaskClosable NSClosableWindowMask
#define NSWindowStyleMaskMiniaturizable NSMiniaturizableWindowMask
#define NSWindowStyleMaskResizable NSResizableWindowMask

#define NSEventModifierFlagShift NSShiftKeyMask
#define NSEventModifierFlagControl NSControlKeyMask
#define NSEventModifierFlagOption NSAlternateKeyMask
#define NSEventModifierFlagCommand NSCommandKeyMask

#define NSEventTypeKeyDown NSKeyDown
#define NSEventTypeKeyUp NSKeyUp
#define NSEventTypeApplicationDefined NSApplicationDefined
#define NSEventTypeFlagsChanged NSFlagsChanged

#define NSEventMaskAny NSAnyEventMask
#endif

// 10.7+ OpenGL profile constants - define for older SDKs
// These will be ignored at runtime on systems that don't support them
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070
#define NSOpenGLPFAOpenGLProfile 99
#define NSOpenGLProfileVersion3_2Core 0x3200
#define NSOpenGLProfileVersionLegacy 0x1000
#endif

// 10.10+ OpenGL 4.1 profile constant
#if MAC_OS_X_VERSION_MAX_ALLOWED < 101000
#define NSOpenGLProfileVersion4_1Core 0x4100
#endif

// Helper functions for 10.7+ backing APIs that work on older systems
// These provide runtime checks for the backing coordinate methods
#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#import <objc/message.h>

// On SDKs < 10.7, the backing coordinate methods don't exist in headers,
// so we must use objc_msgSend to call them dynamically at runtime.
// We define typed function pointer casts to maintain type safety.

// Convert point from view coordinates to backing (pixel) coordinates
// Falls back to identity transform on pre-10.7 systems
static inline NSPoint vtkCocoaConvertPointToBacking(NSView* view, NSPoint point)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([view respondsToSelector:@selector(convertPointToBacking:)])
  {
    return [view convertPointToBacking:point];
  }
#else
  SEL sel = @selector(convertPointToBacking:);
  if ([view respondsToSelector:sel])
  {
    typedef NSPoint (*MsgSendPointPoint)(id, SEL, NSPoint);
    MsgSendPointPoint msgSend = (MsgSendPointPoint)objc_msgSend;
    return msgSend(view, sel, point);
  }
#endif
  return point;
}

// Convert rect from view coordinates to backing (pixel) coordinates
static inline NSRect vtkCocoaConvertRectToBacking(id viewOrScreen, NSRect rect)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([viewOrScreen respondsToSelector:@selector(convertRectToBacking:)])
  {
    return [viewOrScreen convertRectToBacking:rect];
  }
#else
  SEL sel = @selector(convertRectToBacking:);
  if ([viewOrScreen respondsToSelector:sel])
  {
    typedef NSRect (*MsgSendRectRect)(id, SEL, NSRect);
    // For structs larger than register size, some ABIs use objc_msgSend_stret
#if defined(__i386__) || defined(__x86_64__) || defined(__arm64__)
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend;
#else
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend_stret;
#endif
    return msgSend(viewOrScreen, sel, rect);
  }
#endif
  return rect;
}

// Convert size from backing (pixel) coordinates to view coordinates
static inline NSSize vtkCocoaConvertSizeFromBacking(NSView* view, NSSize size)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([view respondsToSelector:@selector(convertSizeFromBacking:)])
  {
    return [view convertSizeFromBacking:size];
  }
#else
  SEL sel = @selector(convertSizeFromBacking:);
  if ([view respondsToSelector:sel])
  {
    typedef NSSize (*MsgSendSizeSize)(id, SEL, NSSize);
    MsgSendSizeSize msgSend = (MsgSendSizeSize)objc_msgSend;
    return msgSend(view, sel, size);
  }
#endif
  return size;
}

// Convert point from backing (pixel) coordinates to view coordinates
static inline NSPoint vtkCocoaConvertPointFromBacking(NSView* view, NSPoint point)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([view respondsToSelector:@selector(convertPointFromBacking:)])
  {
    return [view convertPointFromBacking:point];
  }
#else
  SEL sel = @selector(convertPointFromBacking:);
  if ([view respondsToSelector:sel])
  {
    typedef NSPoint (*MsgSendPointPoint)(id, SEL, NSPoint);
    MsgSendPointPoint msgSend = (MsgSendPointPoint)objc_msgSend;
    return msgSend(view, sel, point);
  }
#endif
  return point;
}

// Set whether the view wants best resolution OpenGL surface (10.7+)
// Does nothing on pre-10.7 systems
static inline void vtkCocoaSetWantsBestResolutionOpenGLSurface(NSView* view, BOOL wantsBest)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([view respondsToSelector:@selector(setWantsBestResolutionOpenGLSurface:)])
  {
    [view setWantsBestResolutionOpenGLSurface:wantsBest];
  }
#else
  SEL sel = @selector(setWantsBestResolutionOpenGLSurface:);
  if ([view respondsToSelector:sel])
  {
    typedef void (*MsgSendVoidBool)(id, SEL, BOOL);
    MsgSendVoidBool msgSend = (MsgSendVoidBool)objc_msgSend;
    msgSend(view, sel, wantsBest);
  }
#endif
}

// Get backing scale factor from window (10.7+)
// Returns 1.0 on pre-10.7 systems
static inline CGFloat vtkCocoaGetBackingScaleFactor(NSWindow* window)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([window respondsToSelector:@selector(backingScaleFactor)])
  {
    return [window backingScaleFactor];
  }
#else
  SEL sel = @selector(backingScaleFactor);
  if ([window respondsToSelector:sel])
  {
    typedef CGFloat (*MsgSendCGFloat)(id, SEL);
    MsgSendCGFloat msgSend = (MsgSendCGFloat)objc_msgSend;
    return msgSend(window, sel);
  }
#endif
  return 1.0;
}

// Convert rect from backing coordinates on NSWindow (10.7+)
// Falls back to identity transform on pre-10.7 systems
static inline NSRect vtkCocoaWindowConvertRectFromBacking(NSWindow* window, NSRect rect)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([window respondsToSelector:@selector(convertRectFromBacking:)])
  {
    return [window convertRectFromBacking:rect];
  }
#else
  SEL sel = @selector(convertRectFromBacking:);
  if ([window respondsToSelector:sel])
  {
    typedef NSRect (*MsgSendRectRect)(id, SEL, NSRect);
#if defined(__i386__) || defined(__x86_64__) || defined(__arm64__)
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend;
#else
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend_stret;
#endif
    return msgSend(window, sel, rect);
  }
#endif
  return rect;
}

// Convert rect to backing coordinates on NSWindow (10.7+)
// Falls back to identity transform on pre-10.7 systems
static inline NSRect vtkCocoaWindowConvertRectToBacking(NSWindow* window, NSRect rect)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([window respondsToSelector:@selector(convertRectToBacking:)])
  {
    return [window convertRectToBacking:rect];
  }
#else
  SEL sel = @selector(convertRectToBacking:);
  if ([window respondsToSelector:sel])
  {
    typedef NSRect (*MsgSendRectRect)(id, SEL, NSRect);
#if defined(__i386__) || defined(__x86_64__) || defined(__arm64__)
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend;
#else
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend_stret;
#endif
    return msgSend(window, sel, rect);
  }
#endif
  return rect;
}

// Convert rect from backing coordinates on NSScreen (10.7+)
// Falls back to identity transform on pre-10.7 systems
static inline NSRect vtkCocoaScreenConvertRectFromBacking(NSScreen* screen, NSRect rect)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
  if ([screen respondsToSelector:@selector(convertRectFromBacking:)])
  {
    return [screen convertRectFromBacking:rect];
  }
#else
  SEL sel = @selector(convertRectFromBacking:);
  if ([screen respondsToSelector:sel])
  {
    typedef NSRect (*MsgSendRectRect)(id, SEL, NSRect);
#if defined(__i386__) || defined(__x86_64__) || defined(__arm64__)
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend;
#else
    MsgSendRectRect msgSend = (MsgSendRectRect)objc_msgSend_stret;
#endif
    return msgSend(screen, sel, rect);
  }
#endif
  return rect;
}

#endif // __OBJC__

// Create handy #defines that indicate the Objective-C memory management model.
// Manual Retain Release, Automatic Reference Counting, or Garbage Collection.
#if defined(__OBJC_GC__)
#define VTK_OBJC_IS_MRR 0
#define VTK_OBJC_IS_ARC 0
#define VTK_OBJC_IS_GC 1
#elif __has_feature(objc_arc)
#define VTK_OBJC_IS_MRR 0
#define VTK_OBJC_IS_ARC 1
#define VTK_OBJC_IS_GC 0
#else
#define VTK_OBJC_IS_MRR 1
#define VTK_OBJC_IS_ARC 0
#define VTK_OBJC_IS_GC 0
#endif

#if __has_feature(objc_arc)
#error VTK does not yet support ARC memory management
#endif

// VTK-HeaderTest-Exclude: vtkCocoaMacOSXSDKCompatibility.h
