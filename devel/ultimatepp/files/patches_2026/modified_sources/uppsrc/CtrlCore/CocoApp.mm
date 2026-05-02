#include "CocoMM.h"

#define LLOG(x) // DLOG(x)

#ifdef GUI_COCOA

@interface AppDelegate : NSObject<NSApplicationDelegate>
{
}
@end

namespace Upp {
NSMenu *Cocoa_DockMenu();
};

@implementation AppDelegate
- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	Upp::GuiLock __;
	return Upp::Cocoa_DockMenu();
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	Upp::GuiLock __;
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(themeChanged:)
                                                     name:@"AppleColorPreferencesChangedNotification"
                                                     object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(themeChanged:)
                                                     name: @"AppleInterfaceThemeChangedNotification"
                                                     object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	Upp::GuiLock __;
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)themeChanged:(NSNotification *)aNotification
{
	Upp::GuiLock __;
	Upp::Ctrl::PostReSkin();
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	Upp::GuiLock __;
	Upp::TopWindow::ShutdownWindows();
	return NSTerminateCancel;
}

@end

namespace Upp {

static NSAutoreleasePool *main_coco_pool;

void SyncPopupFocus(NSWindow *win)
{
	Ctrl *q = Ctrl::GetFocusCtrl();
	if(q) {
		q = q->GetTopCtrl();
		if(q->IsPopUp() && q->GetNSWindow() != win && q->IsCocoActive()) {
			q = q->GetOwner();
			if(q) q->SetFocus();
		}
	}
}

extern const char *sClipFmtsRTF;

id menubar;

void CocoInit(int argc, const char **argv, const char **envptr)
{
	Ctrl::GlobalBackBuffer();
	main_coco_pool = [NSAutoreleasePool new];
	
	[NSApplication sharedApplication];

	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	menubar = [[NSMenu new] autorelease];
	id appMenuItem = [[NSMenuItem new] autorelease];
	[menubar addItem:appMenuItem];
	id appMenu = [[NSMenu new] autorelease];
	id appName = [[NSProcessInfo processInfo] processName];
	id quitTitle = [@"Quit " stringByAppendingString:appName];
	id quitMenuItem = [[[NSMenuItem alloc] initWithTitle:quitTitle
	                                              action:@selector(terminate:)
	                                       keyEquivalent:@"q"] autorelease];
	[appMenu addItem:quitMenuItem];
	[appMenuItem setSubmenu:appMenu];

	[NSApp setMainMenu:menubar];

	[NSApp setDelegate:[[AppDelegate alloc] init]];
	
	NSFont *sysfont = [NSFont systemFontOfSize:0];
	Font::SetFace(0, ToString((CFStringRef)[sysfont familyName]), Font::TTF);
	
	Ctrl::SetUHDEnabled(true);
	bool uhd = true;
#ifdef MAC_OS_X_VERSION_10_7
	// backingScaleFactor available in 10.7+
	NSArray *screens = [NSScreen screens];
	for (NSUInteger i = 0; i < [screens count]; i++) {
		NSScreen *screen = [screens objectAtIndex:i];
		if([screen backingScaleFactor] < 2) {
			uhd = false;
			break;
		}
	}
#else
	// macOS 10.6: no Retina support, always non-UHD
	uhd = false;
#endif
	SetUHDMode(uhd);

	Font::SetDefaultFont(StdFont(fceil(DPI([sysfont pointSize]))));

	GUI_DblClickTime_Write(1000 * [NSEvent doubleClickInterval]);

#ifdef MAC_OS_X_VERSION_10_6
	// Event monitors with blocks - available in 10.6+ but GCC doesn't support blocks
	// Skip event monitors for GCC compatibility - popup focus sync disabled
#ifndef __clang__
	// GCC: skip block-based event monitors
#else
	[NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown)
	  handler:^(NSEvent *e) {
	      SyncPopupFocus(NULL);
    }];
	[NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown)
	  handler:^NSEvent *(NSEvent *e) {
	      SyncPopupFocus([e window]);
	      return e;
    }];
#endif
#endif
    
    sClipFmtsRTF = "rtf";
    
    Ctrl::ReSkin();
    
    EnterGuiMutex();
}

int Ctrl::GetKbdDelay()
{
	Upp::GuiLock __;
	return int(1000 * [NSEvent keyRepeatDelay]);
}

int Ctrl::GetKbdSpeed()
{
	Upp::GuiLock __;
	return int(1000 * [NSEvent keyRepeatInterval]);
}

static NSEvent *current_event;

static NSEvent *GetNextEvent(NSDate *until)
{
	if(!current_event) {
		current_event = [NSApp nextEventMatchingMask:NSEventMaskAny
		                                   untilDate:until
		                                      inMode:NSDefaultRunLoopMode
		                                     dequeue:YES];
		[current_event retain];
	}
	return current_event;
}

static void ReleaseCurrentEvent()
{
	if(current_event) {
		[current_event release];
		current_event = nil;
	}
}

void CocoExit()
{
	ReleaseCurrentEvent();
	[main_coco_pool release];
	LeaveGuiMutex();
}

bool Ctrl::IsWaitingEvent()
{
	return GetNextEvent(nil);
}

bool Ctrl::ProcessEvent(bool *)
{
	ASSERT(IsMainThread());

	AutoreleasePool __;
	
	ONCELOCK {
		[NSApp finishLaunching];
	}
	
	NSEvent *event = GetNextEvent(nil);

	// DLOG("ProcessEvent " << ToString(event.description));

	if(!event)
		return false;
	
	current_event = nil;
	int n = LeaveGuiMutexAll();
	[NSApp sendEvent:event];
	EnterGuiMutex(n);
	[event release];

	return true;
}

void SweepMkImageCache();

bool Ctrl::ProcessEvents(bool *quit)
{
	if(ProcessEvent(quit)) {
		while(ProcessEvent(quit) && (!LoopCtrl || LoopCtrl->InLoop()));
		TimerProc(msecs());
		AnimateCaret();
		[NSApp updateWindows];
		SweepMkImageCache();
		return true;
	}
	TimerProc(msecs());
	SweepMkImageCache();
	return false;
}


void Ctrl::EventLoop(Ctrl *ctrl)
{
	Upp::GuiLock __;
	ASSERT(IsMainThread());
	ASSERT(LoopLevel == 0 || ctrl);
	LoopLevel++;
	LLOG("Entering event loop at level " << LoopLevel);
	Ptr<Ctrl> ploop;
	if(ctrl) {
		ploop = LoopCtrl;
		LoopCtrl = ctrl;
		ctrl->inloop = true;
	}

	bool quit = false;
	ProcessEvents(&quit);
	while(ctrl ? ctrl->IsOpen() && ctrl->InLoop() : GetTopCtrls().GetCount())
	{
//		LLOG(GetSysTime() << " % " << (unsigned)msecs() % 10000 << ": EventLoop / GuiSleep");
		SyncCaret();
		AnimateCaret();
		GuiSleep(20);
//		if(EndSession()) break;
//		LLOG(GetSysTime() << " % " << (unsigned)msecs() % 10000 << ": EventLoop / ProcessEvents");
		ProcessEvents(&quit);
//		LLOG(GetSysTime() << " % " << (unsigned)msecs() % 10000 << ": EventLoop / after ProcessEvents");
	}

	if(ctrl)
		LoopCtrl = ploop;
	LoopLevel--;
	LLOG("Leaving event loop ");
}

static std::atomic<bool> sGuiSleep;

void Ctrl::GuiSleep(int ms)
{
	ASSERT(IsMainThread());
	sGuiSleep = true;
	int n = LeaveGuiMutexAll();
	GetNextEvent([NSDate dateWithTimeIntervalSinceNow:ms / 1000.0]);
	EnterGuiMutex(n);
	sGuiSleep = false;
}

void WakeUpGuiThread(void)
{
	if(sGuiSleep) {
		sGuiSleep = false;
		[NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
		                                    location:NSMakePoint(0, 0)
		                               modifierFlags:0
		                                   timestamp:0.0
		                                windowNumber:0
		                                     context:nil
		                                     subtype:0
		                                       data1:0
		                                       data2:0]
		         atStart:YES];
	}
}

Rect Ctrl::GetWorkArea() const
{
	return StdGetWorkArea();
}

Rect MakeScreenRect(NSScreen *screen, CGRect r)
{
	r.origin.y = [screen frame].size.height - r.origin.y - r.size.height;
	return MakeRect(r, DPI(1));
}

void Ctrl::GetWorkArea(Array<Rect>& rc)
{
	Upp::GuiLock __;
	NSArray *screens = [NSScreen screens];
	for(NSUInteger i = 0; i < [screens count]; i++) {
		NSScreen *screen = [screens objectAtIndex:i];
		CGRect frame = [screen visibleFrame];
		rc.Add(MakeScreenRect(screen, frame));
	}
}


Rect Ctrl::GetVirtualWorkArea()
{
	Array<Rect> rc;
	GetWorkArea(rc);
	Rect r(0, 0, 0, 0);
	for(int i = 0; i < rc.GetCount(); i++)
		if(i)
			r = r | rc[i];
		else
			r = rc[0];
	return r;
}

Rect Ctrl::GetVirtualScreenArea()
{
	bool first = true;
	Rect r(0, 0, 0, 0);
	NSArray *screens = [NSScreen screens];
	for(NSUInteger i = 0; i < [screens count]; i++) {
		NSScreen *screen = [screens objectAtIndex:i];
		CGRect frame = [screen frame];
		Rect sr = MakeScreenRect(screen, frame);
		if(first)
			r = sr;
		else
			r = r | sr;
		first = false;
	}
	return r;
}

Rect Ctrl::GetPrimaryWorkArea()
{
	Array<Rect> rc;
	GetWorkArea(rc);
	return rc.GetCount() ? rc[0] : Rect(0, 0, 0, 0);
}

Rect Ctrl::GetScreenArea(Point pt)
{
	Upp::GuiLock __;
	NSArray *screens = [NSScreen screens];
	for(NSUInteger i = 0; i < [screens count]; i++) {
		NSScreen *screen = [screens objectAtIndex:i];
		CGRect frame = [screen frame];
		Rect rc = MakeScreenRect(screen, frame);
		if(rc.Contains(pt))
			return rc;
	}
	return GetPrimaryScreenArea();
}

Rect Ctrl::GetPrimaryScreenArea()
{
	NSArray *screens = [NSScreen screens];
	if([screens count] > 0) {
		NSScreen *screen = [screens objectAtIndex:0];
		CGRect frame = [screen frame];
		return MakeScreenRect(screen, frame);
	}
	return Rect(0, 0, 1024, 768);
}

bool Ctrl::IsCompositedGui()
{
	return true;
}

Rect Ctrl::GetDefaultWindowRect()
{
	Upp::GuiLock __;
	Rect r  = GetPrimaryWorkArea();
	Size sz = r.GetSize();
	
	static int pos = min(sz.cx / 10, 50);
	pos += 10;
	int cx = sz.cx * 2 / 3;
	int cy = sz.cy * 2 / 3;
	if(pos + cx + 50 > sz.cx || pos + cy + 50 > sz.cy)
		pos = 0;
	return RectC(r.left + pos + 20, r.top + pos + 20, cx, cy);
}

void Ctrl::GuiPlatformGetTopRect(Rect& r) const
{
}

void MMCtrl::SyncRect(CocoView *view)
{
	NSWindow *win = [view window];
	NSScreen *screen = [win screen];
	NSRect winFrame = [win frame];
	NSRect contentRect = [win contentRectForFrameRect:winFrame];
	view->ctrl->SetWndRect(MakeScreenRect(screen, contentRect));
}

TopFrameDraw::TopFrameDraw(Ctrl *ctrl, const Rect& r)
{
	EnterGuiMutex();
	ctrl = ctrl->GetTopCtrl();
	ASSERT(ctrl->GetTop()->coco);
	Rect tr = ctrl->GetScreenRect();
	NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithWindow:ctrl->GetTop()->coco->window];
	Init([gc CGContext], NULL);

	CGContextTranslateCTM(cgHandle, 0, tr.GetHeight());
	CGContextScaleCTM(cgHandle, 1, -1);

	Clipoff(r);
}

TopFrameDraw::~TopFrameDraw()
{
	End();
	CGContextFlush(cgHandle);
	LeaveGuiMutex();
}

String GetSpecialDirectory(int i)
{
	Tuple<int, NSSearchPathDirectory> map[] = {
		{ SF_NSDocumentDirectory, NSDocumentDirectory },
		{ SF_NSUserDirectory, NSUserDirectory },
		{ SF_NSDesktopDirectory, NSDesktopDirectory },
		{ SF_NSDownloadsDirectory, NSDownloadsDirectory },
		{ SF_NSMoviesDirectory, NSMoviesDirectory },
		{ SF_NSMusicDirectory, NSMusicDirectory },
		{ SF_NSPicturesDirectory, NSPicturesDirectory },
	};
	
	if(auto *h = FindTuple(map, __countof(map), i)) {
		NSArray * paths = NSSearchPathForDirectoriesInDomains(h->b, NSUserDomainMask, YES);
		if([paths count])
			return ToString([paths objectAtIndex:0]);
	}
	
	return Null;
};

String GetMusicFolder()	      { return GetSpecialDirectory(SF_NSMusicDirectory); }
String GetPicturesFolder()    { return GetSpecialDirectory(SF_NSPicturesDirectory); }
String GetVideoFolder()       { return GetSpecialDirectory(SF_NSMoviesDirectory); }
String GetDocumentsFolder()   { return GetSpecialDirectory(SF_NSDocumentDirectory); }
String GetDesktopFolder()     { return GetSpecialDirectory(SF_NSDesktopDirectory); }
String GetTemplatesFolder()   { return GetHomeDirectory(); }
String GetDownloadFolder()    { return GetSpecialDirectory(SF_NSDownloadsDirectory); }

void CocoBeep()
{
	NSBeep();
}

extern void (*CocoBeepFn)();

INITBLOCK {
	CocoBeepFn = CocoBeep;
}

};

#endif
