#include <Core/config.h>

#ifdef PLATFORM_COCOA

#include <Carbon/Carbon.h>

#endif

#include <CtrlLib/CtrlLib.h>

#ifdef GUI_COCOA

#include <CtrlCore/CocoMM.h>
#include "ChCocoMM.h"

// Static helper function to perform the actual painting
// Replaces lambda for GCC compatibility (GCC doesn't support Apple blocks)
static void DoPaintChInternal(CGContextRef cg, int type, int value, int state)
{
	if(Upp::IsUHDMode())
		CGContextScaleCTM(cg, 2, 2);
	CGRect cr = CGRectMake(0, 0, 140, 140);
	NSRect frameRect = NSMakeRect(cr.origin.x, cr.origin.y, cr.size.width, cr.size.height);

	if(type == COCO_NSCOLOR) {
		CGContextSaveGState(cg);
		// Use NSColorToCGColor helper for 10.6 compatibility (no .CGColor property)
		CGColorRef fillColor;
		NSColor *nscolor;
		switch(value) {
		case COCO_PAPER:
			nscolor = [NSColor textBackgroundColor];
			break;
		case COCO_SELECTEDTEXT:
			nscolor = [NSColor selectedTextColor];
			break;
		case COCO_SELECTEDPAPER:
			nscolor = [NSColor selectedTextBackgroundColor];
			break;
		case COCO_DISABLED:
			nscolor = [NSColor disabledControlTextColor];
			break;
		case COCO_WINDOW:
			nscolor = [NSColor windowBackgroundColor];
			break;
		case COCO_SELECTEDMENUTEXT:
			nscolor = [NSColor selectedMenuItemTextColor];
			break;
		default:
			nscolor = [NSColor textColor];
			break;
		}
		fillColor = NSColorToCGColor(nscolor);
		CGContextSetFillColorWithColor(cg, fillColor);
		CGColorRelease(fillColor);
		CGContextFillRect(cg, cr);
		CGContextRestoreGState(cg);
	}
	else
	if(type == COCO_NSIMAGE) {
		NSImage *img = [NSImage imageNamed:(value ? NSImageNameInfo : NSImageNameCaution)];
#ifdef MAC_OS_X_VERSION_10_10
		NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES];
		NSGraphicsContext *cgc = [NSGraphicsContext currentContext];
		[NSGraphicsContext setCurrentContext:gc];
		[img drawInRect:NSMakeRect(0, 0, 48, 48)];
		[NSGraphicsContext setCurrentContext:cgc];
#else
		// macOS 10.6-10.9: use graphicsContextWithGraphicsPort:flipped:
		NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort:cg flipped:YES];
		NSGraphicsContext *cgc = [NSGraphicsContext currentContext];
		[NSGraphicsContext setCurrentContext:gc];
		// drawInRect: without fromRect:operation:fraction: not available until 10.9
		[img drawInRect:NSMakeRect(0, 0, 48, 48) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[NSGraphicsContext setCurrentContext:cgc];
#endif
	}
	else {
		CGContextSaveGState(cg);
		[NSGraphicsContext saveGraphicsState];
#ifdef MAC_OS_X_VERSION_10_10
		[NSGraphicsContext setCurrentContext:
			[NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES]];
#else
		[NSGraphicsContext setCurrentContext:
			[NSGraphicsContext graphicsContextWithGraphicsPort:cg flipped:YES]];
#endif

		const NSRect dirtyRect = NSMakeRect(20, 20, 100, 100);

		if(Upp::findarg(type, COCO_SCROLLTHUMB, COCO_SCROLLTRACK) >= 0) {
#ifdef MAC_OS_X_VERSION_10_7
			int cx = [NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy];
#else
			int cx = [NSScroller scrollerWidth];
#endif
			NSScroller *scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, 100, cx)];
			[scroller setFloatValue:0];
			[scroller setKnobProportion:1];
#ifdef MAC_OS_X_VERSION_10_7
			[scroller setKnobStyle:NSScrollerKnobStyleDefault];
			[scroller setScrollerStyle:NSScrollerStyleLegacy];
#endif
			[scroller setFrame:frameRect];
			if(type == COCO_SCROLLTHUMB)
				[scroller drawKnob];
			else
				[scroller drawKnobSlotInRect:NSMakeRect(20, 20, 100, cx) highlight:YES];
			[scroller release];
		}
		else
		if(type == COCO_TEXTFIELD) {
			NSTextField *tf = [[NSTextField alloc] init];
			[tf setEnabled:YES];
			[tf setEditable:YES];
			[tf setBezeled:YES];
			[tf setFrame:NSMakeRect(0, 0, 140, 40)];
			[tf drawRect:dirtyRect];
			[tf release];
		}
		else {
			NSButton *bc = type == COCO_POPUPBUTTON ? [[NSPopUpButton alloc] init] : [[NSButton alloc] init];
			[bc setAllowsMixedState:(type == COCO_CHECKBOX)];
			[bc setTitle:@""];
			[[bc cell] setControlSize:(type == COCO_RADIOBUTTON ? NSControlSizeSmall : NSControlSizeRegular)];
			[bc setFrame:frameRect];
			NSButtonType btnType;
			switch(type) {
			case COCO_CHECKBOX: btnType = NSButtonTypeSwitch; break;
			case COCO_RADIOBUTTON: btnType = NSButtonTypeRadio; break;
			default: btnType = NSButtonTypePushOnPushOff; break;
			}
			[bc setButtonType:btnType];
			[bc setBezelStyle:(type == COCO_BUTTON ? NSBezelStyleRounded : NSBezelStyleRegularSquare)];
			NSControlStateValue stateValue;
			switch(value) {
			case 0: stateValue = NSControlStateValueOff; break;
			case 1: stateValue = NSControlStateValueOn; break;
			default: stateValue = NSControlStateValueMixed; break;
			}
			[bc setState:stateValue];
			[bc highlight:(state == Upp::CTRL_PRESSED)];
			[bc setEnabled:(state != Upp::CTRL_DISABLED)];
			[bc drawRect:dirtyRect];
			[bc release];
		}

		[NSGraphicsContext restoreGraphicsState];
		CGContextRestoreGState(cg);
	}
}

void Coco_PaintCh(void *cgcontext, int type, int value, int state)
{
	CGContextRef cg = (CGContextRef)cgcontext;
	// @available and performAsCurrentDrawingAppearance: require macOS 11.0+ and blocks
	// For 10.6 compatibility with GCC, just call the paint function directly
	// On macOS 11+ with Clang, appearance is handled automatically by the system
	DoPaintChInternal(cg, type, value, state);
}

#endif
