#ifndef flagSKELETON

#include <CtrlLib/CtrlLib.h>

#ifdef GUI_COCOA

#include <CtrlCore/CocoMM.h>

#define LLOG(x) // DLOG(x)

namespace Upp {

struct CocoMenuBar;

};

// Associated object keys for menu data - defined in this file
static char CocoMenuPtrKey;
static char CocoMenuProcKey;

// Use NSMenu directly (typedef) to avoid GCC ObjC runtime issues with subclassing
typedef NSMenu CocoMenu;

// Helper functions to get/set associated menu data
static inline Upp::CocoMenuBar* CocoMenuGetPtr(NSMenu *menu) {
	return (Upp::CocoMenuBar*)objc_getAssociatedObject(menu, &CocoMenuPtrKey);
}
static inline void CocoMenuSetPtr(NSMenu *menu, Upp::CocoMenuBar *p) {
	objc_setAssociatedObject(menu, &CocoMenuPtrKey, (id)p, OBJC_ASSOCIATION_ASSIGN);
}
static inline Upp::Event<Upp::Bar&>* CocoMenuGetProc(NSMenu *menu) {
	return (Upp::Event<Upp::Bar&>*)objc_getAssociatedObject(menu, &CocoMenuProcKey);
}
static inline void CocoMenuSetProc(NSMenu *menu, Upp::Event<Upp::Bar&> *p) {
	objc_setAssociatedObject(menu, &CocoMenuProcKey, (id)p, OBJC_ASSOCIATION_ASSIGN);
}

// Associated object key for storing CocoMenuBar* on each NSMenuItem
// NOTE: CocoMenuItemBarKey is declared extern in CocoMM.h and defined in CocoProc.mm
// so that CocoApp.mm can use the same key for lookups

// Delegate object to handle NSMenuDelegate methods (menuWillOpen/menuDidClose)
@interface CocoMenuDelegate : NSObject<NSMenuDelegate>
@end

// Global delegate instance - shared by all menus
static CocoMenuDelegate *sharedMenuDelegate = nil;

namespace Upp {

struct CocoMenuBar : public Bar {
	CocoMenu *cocomenu;
	Event<Bar&> *proc;  // Heap-allocated to avoid C++ object in ObjC associated storage
	int       lock = 0;
	bool      dockmenu = false;
	int       cy = 0; // estimate of height to place the menu correctly

	bool      just_check = false;
	int       check_i = 0;
	bool      is_same = false;

	struct Item : Bar::Item {
		NSMenuItem      *nsitem = nullptr;
		Event<>          cb;
		One<CocoMenuBar> submenu;
		CocoMenuBar     *bar;

		// flicker prevention - do not recreate top level menu if no changes
		String           text;
		bool             bold = false;
		bool             enabled = false;

		bool    FailCheck(bool chk = false);

		virtual Item& Text(const char *text);
		virtual Item& Key(dword key);
		virtual Item& Image(const class Image& img);
		virtual Item& Check(bool check);
		virtual Item& Radio(bool check);
		virtual Item& Enable(bool _enable = true);
		virtual Item& Bold(bool bold = true);

		~Item() { if(nsitem) [nsitem release]; }
	};

	Array<Item> item;

	void StartCheck() {
		just_check = true;
		check_i = 0;
		is_same = true;
	}

	bool CheckedIsSame() {
		just_check = false;
		return is_same;
	}

	Item& AddItem() {
		if(just_check) {
			if(is_same && check_i < item.GetCount())
				return item[check_i++];
			is_same = false;
			if(item.GetCount() == 0) // need dummy item
				item.Add().bar = this;
			return item[0]; // dummy item, it will be redone anyway
		}
		Item& m = item.Add();
		m.nsitem = [NSMenuItem new];
		m.bar = this;
		[cocomenu addItem:m.nsitem];
		cy += GetStdFontCy();
		return m;
	}

	virtual bool IsMenuBar() const                  { return true; }

	virtual Item& AddItem(Event<> cb) {
		Item& m = AddItem();
		if(!just_check) {
			m.cb = cb;
			// Store bar pointer on the menu item for lookup in the action
			objc_setAssociatedObject(m.nsitem, &CocoMenuItemBarKey, (id)this, OBJC_ASSOCIATION_ASSIGN);
			// Set target to nil - action goes through responder chain to AppDelegate
			// AppDelegate has cocoMenuAction: method to dispatch to the correct CocoMenuBar
			[m.nsitem setTarget:nil];
			[m.nsitem setAction:@selector(cocoMenuAction:)];
			NSLog(@"AddItem: nsitem=%p target=nil (responder chain) bar=%p", m.nsitem, this);
		}
		return m;
	}

	virtual Item&  AddSubMenu(Event<Bar&> proc_) {
		Item& m = AddItem();
		if(!just_check) {
			m.submenu.Create();
			*m.submenu->proc = proc_;
			// Note: submenu items don't need action/target - the submenu itself handles opening
			// The action selector is for the submenu's delegate, not the menu item
			[m.nsitem setSubmenu:m.submenu->cocomenu];
		}
		return m;
	}

	virtual void   AddCtrl(Ctrl *ctrl, int gapsize) {}
	virtual void   AddCtrl(Ctrl *ctrl, Size sz) {}

	virtual bool   IsEmpty() const;
	virtual void   Separator();

	void MenuAction(id item);

	void Set(Event<Bar&> bar);

	void ClearItems() {
		cy = 0;
		just_check = false;
		is_same = false;
		item.Clear();
	}

	void Clear() {
		ClearItems();
		if(cocomenu) {
			CocoMenuSetPtr(cocomenu, NULL);
			CocoMenuSetProc(cocomenu, NULL);
			[cocomenu release];
			cocomenu = NULL;
		}
	}
	void New();

	CocoMenuBar() {
		cocomenu = NULL;
		proc = new Event<Bar&>();
		New();
	}
	~CocoMenuBar() {
		Clear();
		delete proc;
	}
};

void CocoMenuBar::Set(Event<Bar&> bar)
{
	if(lock) return;
	lock++;
	
	StartCheck();
	bar(*this);
	if(!CheckedIsSame()) {
		ClearItems();
		[cocomenu removeAllItems];
		bar(*this);
	}
	lock--;
}

void CocoMenuBar::MenuAction(id sender)
{
	for(const Item& m : item)
		if(m.nsitem == sender) {
			ResetCocoaMouse();
			if(GetParent()) // If not context menu use PostCallback to avoid visual glitches
				PostCallback(m.cb);
			else
				m.cb();
			break;
		}
}

void CocoMenuBar::Separator()
{
	[cocomenu addItem:[NSMenuItem separatorItem]];
	cy += GetStdFontCy();
}

CocoMenuBar::Item& CocoMenuBar::Item::Text(const char *text)
{
	String txt = text;
	if(bar->just_check) {
		if(txt != this->text)
			bar->is_same = false;
		return *this;
	}
	this->text = txt;
	String h;
	while(*text) {
		if(*text == '&') {
			text++;
			if(*text == '&') {
				h.Cat('&');
				text++;
			}
		}
		else
			h.Cat(*text++);
	}
	NSString *s = [NSString stringWithUTF8String:~h];
	[nsitem setTitle:s];
	if(submenu)
		[submenu->cocomenu setTitle:s];
	return *this;
}

bool CocoMenuBar::Item::FailCheck(bool chk)
{
	if(bar->just_check) {
		bar->is_same = bar->is_same && chk;
		return !bar->is_same;
	}
	return false;
}

CocoMenuBar::Item& CocoMenuBar::Item::Key(dword key)
{
	if(FailCheck())
		return *this;
	static Tuple2<int, int> code[] = {
		#include "NSMenuKeys.i"
	};
	auto *v = FindTuple(code, __countof(code), key & ~(K_CTRL|K_SHIFT|K_ALT|K_OPTION));
	if(v) {
		unichar chr = v->b;
		[nsitem setKeyEquivalent:[NSString stringWithCharacters:&chr length:1]];
		[nsitem setKeyEquivalentModifierMask:(key & K_CTRL ? NSEventModifierFlagCommand : 0) |
		                                     (key & K_SHIFT ? NSEventModifierFlagShift : 0) |
		                                     (key & K_ALT ? NSEventModifierFlagControl : 0) |
		                                     (key & K_OPTION ? NSEventModifierFlagOption : 0)];
	}
	return *this;
}

CocoMenuBar::Item& CocoMenuBar::Item::Image(const class Image& img)
{
	if(FailCheck())
		return *this;
	[nsitem setImage:GetNSImage(img)];
	return *this;
}

CocoMenuBar::Item& CocoMenuBar::Item::Check(bool check)
{
	if(FailCheck())
		return *this;
	[nsitem setState:(check ? NSControlStateValueOn : NSControlStateValueOff)];
	return *this;
}

CocoMenuBar::Item& CocoMenuBar::Item::Radio(bool check)
{
	if(FailCheck())
		return *this;
	return Check(check);
}

CocoMenuBar::Item& CocoMenuBar::Item::Enable(bool enable)
{
	if(FailCheck(enabled == enable))
		return *this;
	enabled = enable;
	[nsitem setEnabled:enable];
	return *this;
}

CocoMenuBar::Item& CocoMenuBar::Item::Bold(bool bold)
{
	if(FailCheck(this->bold == bold))
		return *this;
	this->bold = bold;
	return *this;
}

bool CocoMenuBar::IsEmpty() const
{
	return item.GetCount() == 0;
}

// Implementation of New() - must be after CocoMenuDelegate is declared but before it's used
void CocoMenuBar::New() {
	Clear();
	if(!sharedMenuDelegate)
		sharedMenuDelegate = [[CocoMenuDelegate alloc] init];
	cocomenu = [[NSMenu alloc] init];
	[cocomenu setAutoenablesItems:NO];
	CocoMenuSetPtr(cocomenu, this);
	CocoMenuSetProc(cocomenu, proc);
	[cocomenu setDelegate:sharedMenuDelegate];
}

// Function called by AppDelegate when menu item is clicked
// This is exposed so CocoApp.mm can call it
void CocoMenuBarAction(CocoMenuBar *bar, id sender) {
	if(bar)
		bar->MenuAction(sender);
}

}

@implementation CocoMenuDelegate

- (void)menuWillOpen:(NSMenu *)menu {
	Upp::CocoMenuBar *ptr = CocoMenuGetPtr(menu);
	Upp::Event<Upp::Bar&> *proc = CocoMenuGetProc(menu);
	if(ptr && ptr->dockmenu)
		return;
	if(ptr && proc && *proc) {
		ptr->ClearItems();
		[menu removeAllItems];
		(*proc)(*ptr);
	}
}

- (void)menuDidClose:(NSMenu *)menu {
	Upp::CocoMenuBar *ptr = CocoMenuGetPtr(menu);
	if(ptr && ptr->dockmenu)
		return;
	// DO NOT CALL ClearItems here - menu is closed before MenuAction, we need items to find
	// correct callback
	[menu removeAllItems];
}

@end

namespace Upp {

void TopWindow::GuiPlatformDestruct()
{
	if(menubar)
		delete (CocoMenuBar *)menubar;
}

void TopWindow::SetMainMenu(Event<Bar&> menu)
{
	if(!menubar)
		menubar = new CocoMenuBar;
	CocoMenuBar& bar = *(CocoMenuBar *)menubar;
	bar.Set(menu);
	SyncMainMenu(true);
	MainMenu = menu;
}

bool TopWindow::HotKey(dword key)
{
	LLOG("TopWindow::HotKey " << GetKeyDesc(key));
	if(Bar::Scan(MainMenu, key))
		return true;
	return Ctrl::HotKey(key);
}

TopWindow *TopWindow::GetMenuTopWindow(bool dock)
{
	Ctrl *q = GetFocusCtrl();
	if(!q)
		q = GetActiveCtrl();
	if(!q)
		return NULL;
	q = q->GetTopCtrl();
	while(q) {
		TopWindow *w = dynamic_cast<TopWindow *>(q);
		if(w && (dock ? (bool)w->WhenDockMenu : (bool)w->menubar))
			return w;
		q = q->GetOwner();
	}
	return NULL;
}

void TopWindow::SyncMainMenu(bool force)
{
	TopWindow *w = GetMenuTopWindow(false);
	static TopWindow *current;
	if(w != current || force) {
		current = w;
		if(current) {
			CocoMenuBar& bar = *(CocoMenuBar *)current->menubar;
			[NSApp setMainMenu:bar.cocomenu];
			static NSMenu *dummy = [[NSMenu alloc] initWithTitle:@"Unused"];
			ONCELOCK { [dummy retain]; };
			[NSApp setHelpMenu: dummy]; //Avoid placing spotlight search field into Help
		}
	}
}

bool MenuBar::ExecuteHostBar(Ctrl *owner, Point p)
{
	if(host_bar && owner) {
		CocoMenuBar& bar = *(CocoMenuBar *)~host_bar;

		owner = owner->GetTopCtrl();
		
		int h = GetWorkArea().GetHeight();
		bool up = p.y > h / 2 && bar.cy + 2 * GetStdFontCy() + p.y > h;
		
		p -= owner->GetScreenRect().TopLeft();
		
		double scale = 1.0 / DPI(1);
		NSPoint np;
		np.x = scale * p.x;
		np.y = scale * p.y;
		
		ResetCocoaMouse(); // Because we will not get "MouseUp" event...

		return [bar.cocomenu popUpMenuPositioningItem:(up ? bar.item.Top().nsitem : nil)
	                                       atLocation:np
	                                           inView:(NSView *)owner->GetNSView()];
	}
	return false;
}

void MenuBar::CreateHostBar(One<Bar>& bar)
{
	host_bar.Create<CocoMenuBar>();
}

NSMenu *Cocoa_DockMenu() {
	Upp::TopWindow *w = Upp::TopWindow::GetMenuTopWindow(true);

	if(w && w->WhenDockMenu) {
		static Upp::CocoMenuBar bar;
		bar.dockmenu = true;
		bar.Clear();
		bar.cocomenu = [[[NSMenu alloc] initWithTitle:@"DocTile Menu"] autorelease];
		[bar.cocomenu setAutoenablesItems:NO];
		CocoMenuSetPtr(bar.cocomenu, &bar);
		CocoMenuSetProc(bar.cocomenu, bar.proc);
		if(!sharedMenuDelegate)
			sharedMenuDelegate = [[CocoMenuDelegate alloc] init];
		[bar.cocomenu setDelegate:sharedMenuDelegate];
		w->WhenDockMenu(bar);
		CocoMenu *m = bar.cocomenu;
		bar.cocomenu = NULL;
		return m;
	}
	return nil;
}

};

#endif

#endif
