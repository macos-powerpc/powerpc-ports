#ifndef _CtrlCore_CocoMM_h_
#define _CtrlCore_CocoMM_h_

#include <Core/config.h>

#if defined(PLATFORM_COCOA) && !defined(VIRTUALGUI)

// Disable old-style Carbon assertion macros (check, verify, require, etc.)
// to avoid conflicts with identifiers in U++ code (e.g., IMAGE_ID(check))
// See: https://github.com/opencv/opencv/issues/6047
#ifndef __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES
#define __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES 0
#endif

#define Point NS_Point
#define Rect  NS_Rect
#define Size  NS_Size
#include <AppKit/AppKit.h>
#undef  Point
#undef  Rect
#undef  Size

// macOS 10.6 SDK compatibility - modern names for older constants
#ifndef MAC_OS_X_VERSION_10_12
  #define NSEventModifierFlagShift     NSShiftKeyMask
  #define NSEventModifierFlagControl   NSControlKeyMask
  #define NSEventModifierFlagOption    NSAlternateKeyMask
  #define NSEventModifierFlagCommand   NSCommandKeyMask
  #define NSEventModifierFlagCapsLock  NSAlphaShiftKeyMask
  #define NSEventModifierFlagNumericPad NSNumericPadKeyMask

  #define NSEventTypeKeyDown           NSKeyDown
  #define NSEventTypeKeyUp             NSKeyUp
  #define NSEventTypeFlagsChanged      NSFlagsChanged
  #define NSEventTypeLeftMouseDown     NSLeftMouseDown
  #define NSEventTypeLeftMouseUp       NSLeftMouseUp
  #define NSEventTypeRightMouseDown    NSRightMouseDown
  #define NSEventTypeRightMouseUp      NSRightMouseUp
  #define NSEventTypeOtherMouseDown    NSOtherMouseDown
  #define NSEventTypeOtherMouseUp      NSOtherMouseUp
  #define NSEventTypeLeftMouseDragged  NSLeftMouseDragged
  #define NSEventTypeRightMouseDragged NSRightMouseDragged
  #define NSEventTypeOtherMouseDragged NSOtherMouseDragged
  #define NSEventTypeMouseMoved        NSMouseMoved
  #define NSEventTypeScrollWheel       NSScrollWheel
  #define NSEventTypeMouseEntered      NSMouseEntered
  #define NSEventTypeMouseExited       NSMouseExited
  #define NSEventTypeApplicationDefined NSApplicationDefined

  #define NSWindowStyleMaskTitled      NSTitledWindowMask
  #define NSWindowStyleMaskClosable    NSClosableWindowMask
  #define NSWindowStyleMaskMiniaturizable NSMiniaturizableWindowMask
  #define NSWindowStyleMaskResizable   NSResizableWindowMask
  #define NSWindowStyleMaskBorderless  NSBorderlessWindowMask

  #define NSEventMaskAny               NSAnyEventMask
  #define NSEventMaskLeftMouseDown     NSLeftMouseDownMask

  // NSControlSize constants renamed in 10.12
  #define NSControlSizeRegular         NSRegularControlSize
  #define NSControlSizeSmall           NSSmallControlSize
  #define NSControlSizeMini            NSMiniControlSize

  // NSButtonType constants renamed in 10.12
  #define NSButtonTypeMomentaryLight       NSMomentaryLightButton
  #define NSButtonTypePushOnPushOff        NSPushOnPushOffButton
  #define NSButtonTypeToggle               NSToggleButton
  #define NSButtonTypeSwitch               NSSwitchButton
  #define NSButtonTypeRadio                NSRadioButton
  #define NSButtonTypeMomentaryChange      NSMomentaryChangeButton
  #define NSButtonTypeOnOff                NSOnOffButton
  #define NSButtonTypeMomentaryPushIn      NSMomentaryPushInButton

  // NSBezelStyle constants renamed in 10.12
  #define NSBezelStyleRounded              NSRoundedBezelStyle
  #define NSBezelStyleRegularSquare        NSRegularSquareBezelStyle
  #define NSBezelStyleShadowlessSquare     NSShadowlessSquareBezelStyle
  #define NSBezelStyleSmallSquare          NSSmallSquareBezelStyle
  #define NSBezelStyleRoundedDisclosure    NSRoundedDisclosureBezelStyle
  #define NSBezelStyleInline               NSInlineBezelStyle
#endif

#ifndef MAC_OS_X_VERSION_10_9
  #define NSModalResponseOK            NSOKButton
  #define NSModalResponseCancel        NSCancelButton
#endif

#ifndef MAC_OS_X_VERSION_10_13
  #define NSControlStateValueOn        NSOnState
  #define NSControlStateValueOff       NSOffState
  #define NSControlStateValueMixed     NSMixedState
#endif

// macOS 10.7+ scroller styles - not available on 10.6
#ifndef MAC_OS_X_VERSION_10_7
  #define NSScrollerStyleLegacy        0
  #define NSScrollerStyleOverlay       1
  #define NSScrollerKnobStyleDefault   0
  #define NSScrollerKnobStyleDark      1
  #define NSScrollerKnobStyleLight     2
#endif

// NSControlStateValue type alias (was NSInteger before 10.10)
#ifndef MAC_OS_X_VERSION_10_10
  typedef NSInteger NSControlStateValue;
#endif

// Helper function: Convert NSColor to CGColorRef (for 10.6 compatibility)
// NSColor.CGColor property not available until macOS 10.8
inline CGColorRef NSColorToCGColor(NSColor *nscolor) {
    NSColor *rgbColor = [nscolor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    if(!rgbColor)
        rgbColor = [nscolor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if(!rgbColor) {
        CGFloat components[4] = {1.0, 1.0, 1.0, 1.0};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
        CGColorRef cgColor = CGColorCreate(colorSpace, components);
        CGColorSpaceRelease(colorSpace);
        return cgColor;
    }
    CGFloat components[4];
    [rgbColor getRed:&components[0] green:&components[1] blue:&components[2] alpha:&components[3]];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGColorRef cgColor = CGColorCreate(colorSpace, components);
    CGColorSpaceRelease(colorSpace);
    return cgColor;
}

#endif

#include "CtrlCore.h"

#ifdef GUI_COCOA

namespace Upp {

template <class T>
struct CFRef {
	T ptr;
	T operator~()   { return ptr; }
	operator T()    { return ptr; }
	T  operator->() { return ptr; }
	T  Detach()     { T h = ptr; ptr = NULL; return h; }
	CFRef(T p)      { ptr = p; }
	~CFRef()        { if(ptr) CFRelease(ptr); }
};

struct AutoreleasePool {
	NSAutoreleasePool *pool;

	AutoreleasePool() {
		pool = [[NSAutoreleasePool alloc] init];
	}
	~AutoreleasePool() {
	    [pool release];
	}
};

CGImageRef createCGImage(const Image& img);

NSImage *GetNSImage(const Image& img);

// From Draw/FontCoco.cpp
WString ToWString(CFStringRef s);
String  ToString(CFStringRef s);

inline WString ToWString(NSString *s) { return ToWString((CFStringRef)s); }
inline String  ToString(NSString *s)  { return ToString((CFStringRef)s); }

inline CGContextRef GetCG(SystemDraw& w) { return (CGContextRef)w.GetCGHandle(); }

#define      cgHandle   (CGContextRef)handle

struct PointCG {
	int x, y;

	operator CGPoint() const { return CGPointMake(x, y); }
	
	PointCG(int x, int y) : x(x), y(y) {}
	PointCG();
};

struct RectCG {
	int x, y, cx, cy;

	operator CGRect() const { return CGRectMake(x, y, cx, cy); }
	
	RectCG(int x, int y, int cx, int cy) : x(x), y(y), cx(cx), cy(cy) {}
	RectCG();
};

NSRect DesktopRect(const Upp::Rect& r);

}

// Use objc_setAssociatedObject/objc_getAssociatedObject to store data
// This avoids GCC ObjC runtime issues with ivars
#import <objc/runtime.h>

// Keys for associated objects - must be unique addresses
static char CocoViewCtrlKey;
static char CocoWindowCtrlKey;
static char CocoWindowActiveKey;

@interface CocoView : NSView <NSWindowDelegate, NSTextInputClient>
@end

// Use NSWindow directly instead of subclassing to avoid GCC ObjC runtime issues
typedef NSWindow CocoWindow;

// Helper functions to get/set associated ctrl pointer
static inline Upp::Ctrl* CocoViewGetCtrl(CocoView *view) {
	return (Upp::Ctrl*)objc_getAssociatedObject(view, &CocoViewCtrlKey);
}
static inline void CocoViewSetCtrl(CocoView *view, Upp::Ctrl *c) {
	objc_setAssociatedObject(view, &CocoViewCtrlKey, (id)c, OBJC_ASSOCIATION_ASSIGN);
}
static inline Upp::Ctrl* CocoWindowGetCtrl(CocoWindow *win) {
	return (Upp::Ctrl*)objc_getAssociatedObject(win, &CocoWindowCtrlKey);
}
static inline void CocoWindowSetCtrl(CocoWindow *win, Upp::Ctrl *c) {
	objc_setAssociatedObject(win, &CocoWindowCtrlKey, (id)c, OBJC_ASSOCIATION_ASSIGN);
}
static inline bool CocoWindowGetActive(CocoWindow *win) {
	return objc_getAssociatedObject(win, &CocoWindowActiveKey) != nil;
}
static inline void CocoWindowSetActive(CocoWindow *win, bool a) {
	objc_setAssociatedObject(win, &CocoWindowActiveKey, a ? (id)1 : nil, OBJC_ASSOCIATION_ASSIGN);
}

struct Upp::MMCtrl {
	static void SyncRect(CocoView *view);
};

struct Upp::CocoTop {
	CocoWindow *window = NULL;
	CocoView *view = NULL;
	Ptr<Ctrl> owner;
};

void SyncRect(CocoView *view);

inline Upp::Rect MakeRect(const CGRect& r, int dpi) {
	return Upp::RectC(dpi * r.origin.x, dpi * r.origin.y, dpi * r.size.width, dpi * r.size.height);
}

inline CGRect CGRectDPI(const Upp::Rect& r) {
	if(Upp::IsUHDMode())
		return CGRectMake(0.5 * r.left, 0.5 * r.top, 0.5 * r.GetWidth(), 0.5 * r.GetHeight());
	else
		return CGRectMake(r.left, r.top, r.GetWidth(), r.GetHeight());
}

#endif

#endif
