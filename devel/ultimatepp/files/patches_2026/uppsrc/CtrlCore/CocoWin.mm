#include "CocoMM.h"

#ifdef GUI_COCOA

#define LLOG(x)

// Method swizzling for NSWindow to override canBecomeKeyWindow/canBecomeMainWindow
// This avoids subclassing NSWindow which causes crashes with GCC's ObjC runtime

static IMP sOriginalCanBecomeKeyWindow = NULL;
static IMP sOriginalCanBecomeMainWindow = NULL;

// Replacement for canBecomeKeyWindow - checks if our Ctrl is enabled
// Note: The 'active' flag is only used for popup menus/tooltips that should never become key
// Dialogs (TopWindow) should always be able to become key if enabled
static BOOL Swizzled_canBecomeKeyWindow(id self, SEL _cmd)
{
	Upp::Ctrl *ctrl = CocoWindowGetCtrl((CocoWindow*)self);
	// If this is our window, use our logic
	if(ctrl) {
		Upp::GuiLock __;
		// Check if it's a TopWindow (dialog) - these should always be able to become key if enabled
		// PopUp windows (menus, tooltips) have active=false and should not become key
		bool active = CocoWindowGetActive((CocoWindow*)self);
		Upp::TopWindow *tw = dynamic_cast<Upp::TopWindow*>(ctrl);
		bool isTopWindow = (tw != NULL);
		BOOL result = (active || isTopWindow) && ctrl->IsEnabled();
		NSLog(@"canBecomeKeyWindow: ctrl=%p active=%d tw=%p isTopWindow=%d enabled=%d result=%d",
		      ctrl, (int)active, tw, (int)isTopWindow, (int)ctrl->IsEnabled(), (int)result);
		return result;
	}
	// Otherwise call original
	NSLog(@"canBecomeKeyWindow: no ctrl, calling original");
	if(sOriginalCanBecomeKeyWindow)
		return ((BOOL(*)(id, SEL))sOriginalCanBecomeKeyWindow)(self, _cmd);
	return YES; // NSWindow default
}

// Replacement for canBecomeMainWindow - checks if TopWindow without owner
static BOOL Swizzled_canBecomeMainWindow(id self, SEL _cmd)
{
	Upp::Ctrl *ctrl = CocoWindowGetCtrl((CocoWindow*)self);
	// If this is our window, use our logic
	if(ctrl) {
		Upp::GuiLock __;
		// Main window must be a TopWindow, enabled, and without owner
		// The 'active' flag is not relevant for main window status
		Upp::TopWindow *tw = dynamic_cast<Upp::TopWindow *>(ctrl);
		return tw && ctrl->IsEnabled() && !ctrl->GetOwner();
	}
	// Otherwise call original
	if(sOriginalCanBecomeMainWindow)
		return ((BOOL(*)(id, SEL))sOriginalCanBecomeMainWindow)(self, _cmd);
	return YES; // NSWindow default
}

static void SwizzleNSWindowMethods()
{
	static bool swizzled = false;
	if(swizzled) return;
	swizzled = true;

	NSLog(@"SwizzleNSWindowMethods: swizzling NSWindow methods");
	Class windowClass = [NSWindow class];

	// Swizzle canBecomeKeyWindow
	Method origKey = class_getInstanceMethod(windowClass, @selector(canBecomeKeyWindow));
	if(origKey) {
		sOriginalCanBecomeKeyWindow = method_getImplementation(origKey);
		method_setImplementation(origKey, (IMP)Swizzled_canBecomeKeyWindow);
		NSLog(@"SwizzleNSWindowMethods: canBecomeKeyWindow swizzled, orig=%p new=%p", sOriginalCanBecomeKeyWindow, Swizzled_canBecomeKeyWindow);
	} else {
		NSLog(@"SwizzleNSWindowMethods: canBecomeKeyWindow NOT FOUND");
	}

	// Swizzle canBecomeMainWindow
	Method origMain = class_getInstanceMethod(windowClass, @selector(canBecomeMainWindow));
	if(origMain) {
		sOriginalCanBecomeMainWindow = method_getImplementation(origMain);
		method_setImplementation(origMain, (IMP)Swizzled_canBecomeMainWindow);
		NSLog(@"SwizzleNSWindowMethods: canBecomeMainWindow swizzled");
	} else {
		NSLog(@"SwizzleNSWindowMethods: canBecomeMainWindow NOT FOUND");
	}
}

namespace Upp {

static Vector<Ptr<Ctrl>> mmtopctrl; // should work without Ptr, but let us be defensive....

bool Ctrl::always_use_bundled_icon = false;

Ctrl *Ctrl::GetOwner()
{
	GuiLock __;
	return top && GetTop()->coco ? GetTop()->coco->owner : NULL;
}

Ctrl *Ctrl::GetActiveCtrl()
{
	GuiLock __;
	for(int i = 0; i < mmtopctrl.GetCount(); i++) {
		Ctrl *p = mmtopctrl[i];
		if(p && p->top && p->GetTop()->coco && [p->GetTop()->coco->window isKeyWindow])
			return p;
	}
	return lastActive;
}

bool Ctrl::SetWndFocus()
{
	GuiLock __;
	if(top && GetTop()->coco) {
		[GetTop()->coco->window orderFront:GetTop()->coco->window];
		if([GetTop()->coco->window canBecomeKeyWindow])
			[GetTop()->coco->window makeKeyWindow];
		if(dynamic_cast<TopWindow *>(this) && [GetTop()->coco->window canBecomeMainWindow])
			[GetTop()->coco->window makeMainWindow];
	}
	return true;
}

bool Ctrl::HasWndFocus() const
{
	GuiLock __;
	return GetActiveCtrl() == this;
}


void Ctrl::SetWndForeground()
{
	GuiLock __;
	SetWndFocus();
}

bool Ctrl::IsWndForeground() const
{
	GuiLock __;
	return HasWndFocus();
}

NSRect DesktopRect(const Rect& r)
{
	double scalei = 1.0 / DPI(1);
	return NSMakeRect(scalei * r.left,
	                  scalei * (Ctrl::GetScreenArea(r.TopLeft()).GetHeight() - r.top - r.GetHeight()),
	                  scalei * r.GetWidth(), scalei * r.GetHeight());
}

void *Ctrl::GetNSWindow() const
{
	return top && GetTop()->coco ? GetTop()->coco->window : NULL;
}

void *Ctrl::GetNSView() const
{
	return top && GetTop()->coco ? GetTop()->coco->view : NULL;
}

void Ctrl::DoCancelPreedit()
{
	[[NSTextInputContext currentInputContext] discardMarkedText];
}

void Ctrl::Create(Ctrl *owner, dword style, bool active)
{
	cancel_preedit = DoCancelPreedit; // We really need this just once, but whatever..

	// Swizzle NSWindow methods for canBecomeKeyWindow/canBecomeMainWindow (GCC compatibility)
	SwizzleNSWindowMethods();
	
	if(owner)
		owner = owner->GetTopCtrl();

	SetTop(new Top);
	GetTop()->coco = new CocoTop;
	GetTop()->coco->owner = owner;
	
	NSRect frame = DesktopRect(GetRect());
	CocoWindow *window = [[CocoWindow alloc] initWithContentRect:frame styleMask: style
	                                         backing:NSBackingStoreBuffered defer:false];
	GetTop()->coco->window = window;
	if(owner && owner->top && owner->GetTop()->coco)
		[owner->GetTop()->coco->window addChildWindow:window ordered:NSWindowAbove];

	CocoWindowSetCtrl(window, this);
	CocoWindowSetActive(window, active);
	[window setBackgroundColor:[NSColor clearColor]];

	isopen = true;

	CocoView *view = [[[CocoView alloc] initWithFrame:frame] autorelease];
	CocoViewSetCtrl(view, this);
	GetTop()->coco->view = view;
	[window setContentView:view];
	[window setDelegate:view];
	[window setAcceptsMouseMovedEvents:YES];
	BOOL frResult = [window makeFirstResponder:view];
	NSLog(@"Create: window=%p view=%p makeFirstResponder=%d", window, view, (int)frResult);
	[window makeKeyAndOrderFront:window];
	NSLog(@"Create: after makeKeyAndOrderFront, isKeyWindow=%d firstResponder=%p",
	      (int)[window isKeyWindow], [window firstResponder]);
	
	ONCELOCK {
		[NSApp activateIgnoringOtherApps:YES];
	}

	MMCtrl::SyncRect(view);
	mmtopctrl.Add(this);

	RegisterCocoaDropFormats();
	
	StateH(OPEN);
}

void Ctrl::WndDestroy()
{
	LLOG("WndDestroy " << Name());
	NSLog(@"WndDestroy: ctrl=%p window=%p isTopWindow=%d",
	      this, top ? GetTop()->coco->window : nil,
	      dynamic_cast<TopWindow*>(this) != NULL);
	if(!top)
		return;
	bool focus = HasFocusDeep();
	Ptr<Ctrl> owner = GetOwner();

	auto* coco = GetTop()->coco;
	auto* window = coco->window;

	NSLog(@"WndDestroy: before close, window=%p isVisible=%d retainCount=%lu",
	      window, (int)[window isVisible], (unsigned long)[window retainCount]);
	[window setCollectionBehavior:NSWindowCollectionBehaviorTransient];
	[window orderOut:nil];  // Force window to hide immediately
	[window close];
	NSLog(@"WndDestroy: after close, isVisible=%d", (int)[window isVisible]);

	delete coco;
	DeleteTop();

	popup = isopen = false;
	int ii = FindIndex(mmtopctrl, this);
	if(ii >= 0)
		mmtopctrl.Remove(ii);
	if(owner && owner->IsOpen() && (focus || !GetFocusCtrl()))
		owner->SetWndFocus();
}

Vector<Ctrl *> Ctrl::GetTopCtrls()
{
	Vector<Ctrl *> h;
	for(Ctrl *p : mmtopctrl)
		if(p) h.Add(p);
	return h;
}

void WakeUpGuiThread();

void Ctrl::WndInvalidateRect(const Rect& r)
{
	GuiLock __;
	if(top) {
		CGRect cgr = CGRectDPI(r.Inflated(10, 10));
		NSRect nsr = NSMakeRect(cgr.origin.x, cgr.origin.y, cgr.size.width, cgr.size.height);
		if(IsMainThread())
			[GetTop()->coco->view setNeedsDisplayInRect:nsr];
		else {
			Ptr<Ctrl> ctrl = this;
			PostCallback([=] {
				if(ctrl)
					[ctrl->GetTop()->coco->view setNeedsDisplayInRect:nsr];
			});
		}
	}
}

void Ctrl::WndScrollView(const Rect& r, int dx, int dy)
{
	GuiLock __;
	LLOG("Scroll View " << r);
	WndInvalidateRect(r);
}

bool Ctrl::IsWndOpen() const {
	GuiLock __;
//	DLOG("IsWndOpen " << Upp::Name(this) << ": " << (bool)top);
	return top;
}

void Ctrl::PopUp(Ctrl *owner, bool savebits, bool activate, bool dropshadow, bool topmost)
{
	Create(owner ? owner->GetTopCtrl() : GetActiveCtrl(), NSWindowStyleMaskBorderless, 0);
	popup = true;
	if(activate && IsEnabled())
		SetFocus();
}

dword TopWindow::GetMMStyle() const
{
	dword style = 0;
	if(!frameless)
		style |= NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable;
	if(minimizebox)
		style |= NSWindowStyleMaskMiniaturizable;
//	if(maximizebox)
//		style |= ;
	return style;
}

void TopWindow::Open(Ctrl *owner)
{
	GuiLock __;
	SetupRect(owner);
	if((owner && center == 1) || center == 2)
		SetRect((center == 1 ? owner->GetRect() : owner ? owner->GetWorkArea()
		                                                : GetPrimaryWorkArea())
		        .CenterRect(GetRect().GetSize()));
	placefocus = true;
	Create(owner, GetMMStyle(), true);
	SyncCaption();
	SyncSizeHints();
	if(state == MAXIMIZED)
		Maximize();
	if(state == MINIMIZED)
		Minimize();
	// Note: window is activated and PlaceFocus invoked by event, later
}

void TopWindow::Open()
{
	Open(GetActiveCtrl());
}

void TopWindow::OpenMain()
{
	Open(NULL);
}

void TopWindow::SyncTitle()
{
	GuiLock __;
	if(top) {
		LLOG("SyncTitle " << title);
		CFRef<CFStringRef> s = CFStringCreateWithCString(NULL, (const char *)~title.ToString(), kCFStringEncodingUTF8);
		[GetTop()->coco->window setTitle:(NSString *)~s];
	}
}

void Ctrl::SyncAppIcon()
{
	if(always_use_bundled_icon)
		return;
	
	Ctrl *q = GetFocusCtrl();
	if(!q)
		q = lastActive;
	if(q) {
		q = q->GetTopWindow();
		while(q->GetOwner())
			q = q->GetOwner();
		TopWindow *w = dynamic_cast<TopWindow *>(q);
		if(w) {
			Image m = Nvl(w->GetLargeIcon(), w->GetIcon());
			if(!IsNull(m))
				SetNSAppImage(m);
		}
	}
}

void TopWindow::SyncCaption()
{
	GuiLock __;
	if(top) {
		SyncTitle();
		NSWindow* window = GetTop()->coco->window;

		// NSWindowStyleMask is typedef'd in 10.12+; use NSUInteger for 10.6 compatibility
		NSUInteger mask = [window styleMask];
		mask = minimizebox ? (mask | NSWindowStyleMaskMiniaturizable)
		                   : (mask & ~NSWindowStyleMaskMiniaturizable);
		mask = maximizebox ? (mask | NSWindowStyleMaskResizable)
		                   : (mask & ~NSWindowStyleMaskResizable);

		[window setStyleMask:mask];
	}
	SyncAppIcon();
}

CGSize MMFrameSize(Size sz, dword style)
{
	double scale = 1.0 / DPI(1);
	NSRect contentRect = NSMakeRect(100, 100, scale * sz.cx, scale * sz.cy);
	NSRect frameRect = [NSWindow frameRectForContentRect:contentRect styleMask:style];
	return CGSizeMake(frameRect.size.width, frameRect.size.height);
}

void TopWindow::SyncSizeHints()
{
	GuiLock __;
	if(top) {
		NSWindow *window = GetTop()->coco->window;
		dword style = GetMMStyle();
		Size sz = GetRect().GetSize();
		CGSize minSz = MMFrameSize(sizeable ? GetMinSize() : sz, style);
		CGSize maxSz = MMFrameSize(sizeable ? GetMaxSize() : sz, style);
		[window setMinSize:NSMakeSize(minSz.width, minSz.height)];
		[window setMaxSize:NSMakeSize(maxSz.width, maxSz.height)];
	}
}

Rect Ctrl::GetWndScreenRect() const
{ // THIS IS NOT NEEDED
	GuiLock __;
	Rect r = GetRect();
	return r;
}

void Ctrl::WndSetPos(const Rect& rect)
{
	GuiLock __;
	if(top)
		[GetTop()->coco->window setFrame:
			[GetTop()->coco->window frameRectForContentRect:DesktopRect(rect)]
			display:YES];
}

void TopWindow::SerializePlacement(Stream& s, bool reminimize)
{
	GuiLock __;
	int version = 0;
	s / version;
	Rect rect = GetRect();
	s % rect;
	if(s.IsLoading())
		SetRect(rect);
}

void TopWindow::Maximize(bool effect)
{
	state = MAXIMIZED;
	if(top && GetTop()->coco && GetTop()->coco->window && ![GetTop()->coco->window isZoomed]) {
		if(effect)
			[GetTop()->coco->window performZoom:GetTop()->coco->window];
		else
			[GetTop()->coco->window zoom:GetTop()->coco->window];
	}
}

void TopWindow::Minimize(bool effect)
{
	state = MINIMIZED;
	if(top && GetTop()->coco && GetTop()->coco->window && ![GetTop()->coco->window isMiniaturized]) {
		if(effect)
			[GetTop()->coco->window performMiniaturize:GetTop()->coco->window];
		else
			[GetTop()->coco->window miniaturize:GetTop()->coco->window];
	}
}

void TopWindow::Overlap(bool effect)
{
	state = OVERLAPPED;
	if(top && GetTop()->coco && GetTop()->coco->window && [GetTop()->coco->window isZoomed])
		[GetTop()->coco->window zoom:GetTop()->coco->window];
	if(top && GetTop()->coco && GetTop()->coco->window && [GetTop()->coco->window isMiniaturized])
		[GetTop()->coco->window deminiaturize:GetTop()->coco->window];
}

bool Ctrl::IsCocoActive() const
{
	return top && GetTop()->coco && GetTop()->coco->window && CocoWindowGetActive(GetTop()->coco->window);
}

}

#endif
