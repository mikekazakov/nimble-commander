#include <Carbon/Carbon.h>
#include "FilterPopUpMenu.h"


/* Set (and get) the view for a menu item.  By default, a menu item has a nil view.
A menu item with a view does not draw its title, state, font, or other standard drawing attributes, and assigns drawing responsibility entirely to the view.  Keyboard equivalents and type-select continue to use the key equivalent and title as normal.
A menu item with a view sizes itself according to the view's frame, and the width of the other menu items.  The menu item will always be at least as wide as its view, but it may be wider.  If you want your view to auto-expand to fill the menu item, then make sure that its autoresizing mask has NSViewWidthSizable set; in that case, the view's width at the time setView: is called will be treated as the minimum width for the view.  A menu will resize itself as its containing views change frame size.  Changes to the view's frame during tracking are reflected immediately in the menu.
A view in a menu item will receive mouse and keyboard events normally.  During non-sticky menu tracking (manipulating menus with the mouse button held down), a view in a menu item will receive mouseDragged: events.
Animation is possible via the usual mechanism (set a timer to call setNeedsDisplay: or display), but because menu tracking occurs in the NSEventTrackingRunLoopMode, you must add the timer to the run loop in that mode.
When the menu is opened, the view is added to a window; when the menu is closed the view is removed from the window.  Override viewDidMoveToWindow in your view for a convenient place to start/stop animations, reset tracking rects, etc., but do not attempt to move or otherwise modify the window.
When a menu item is copied via NSCopying, any attached view is copied via archiving/unarchiving.  Menu item views are not supported in the Dock menu. */



//    NSMenu *menu = [[NSMenu alloc] init];

//- (void)update;

@interface FilterPopUpMenu()
- (void) updateFilter:(NSString*)_filter;
@end

@interface FilterPopUpMenuItem : NSView<NSTextFieldDelegate>
//@property (weak) FilterPopUpMenu *parentMenu;
//@property (nonatomic) NSString *title;
@end

@implementation FilterPopUpMenu
{
    NSString *m_Filter;
}

- (instancetype)initWithTitle:(NSString *)title
{
    self = [super initWithTitle:title];
    if( self ) {
        auto header_view = [[FilterPopUpMenuItem alloc] initWithFrame:NSMakeRect(0, 0, 100, 20)];
//        header_view.parentMenu = self;
        
        auto header_item = [[NSMenuItem alloc] init];
        header_item.title = title;
        header_item.view = header_view;
        [self addItem:header_item];
    }
    return self;
}

//NSCarbonMenuWindow
- (void) updateFilter:(NSString*)_filter
{
    m_Filter = _filter;
    [self updateVisibility];
//    [NSRunLoop.currentRunLoop performSelector:@selector(updateVisibility)
//                                       target:self
//                                     argument:nil
//                                        order:0
//                                        modes:@[NSEventTrackingRunLoopMode]];
}

- (bool) validateItem:(NSMenuItem*)_item
{
    if( !m_Filter || m_Filter.length == 0)
        return true;
    if( _item.isSeparatorItem )
        return false;
    return [_item.title rangeOfString:m_Filter
                              options:NSCaseInsensitiveSearch].length > 0;
}

- (void) updateVisibility
{
    auto items = self.itemArray;

    for( int i = 1; i < items.count; ++i ) {
        auto item = [items objectAtIndex:i];
        item.hidden = ![self validateItem:item];
    }
}

@end



@implementation FilterPopUpMenuItem
{
    NSTextField *m_Title;
    NSTextField *m_Query;
    EventHandlerRef m_EventHandler;
}

//@synthesize parentMenu;

- (instancetype) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect]) {
        self.autoresizingMask = NSViewWidthSizable;

        m_Title = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        m_Title.translatesAutoresizingMaskIntoConstraints = false;
        m_Title.stringValue = @"Frequently Visited";
        m_Title.bordered = false;
        m_Title.editable = false;
        m_Title.enabled = false;
        m_Title.usesSingleLineMode = true;
        m_Title.drawsBackground = false;
        m_Title.font = [NSFont menuFontOfSize:14];
//        m_Title.textColor = NSColor.secondaryLabelColor;
        m_Title.textColor = NSColor.disabledControlTextColor;
        
//        @property (class, strong, readonly) NSColor *selectedMenuItemTextColor;     // Highlight color for menu text
        
        [self addSubview:m_Title];


        m_Query = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        m_Query.translatesAutoresizingMaskIntoConstraints = false;
        m_Query.stringValue = @"";
        m_Query.editable = true;
        m_Query.enabled = true;
        m_Query.usesSingleLineMode = true;
        m_Query.lineBreakMode = NSLineBreakByTruncatingHead;
        m_Query.placeholderString = @"Type to filter";
        m_Query.delegate = self;
        m_Query.bordered = true;
        m_Query.bezeled = true;
        m_Query.bezelStyle = NSTextFieldRoundedBezel;
        m_Query.font = [NSFont menuFontOfSize:0];
//        m_Query.controlSize = NSControlSizeMini;
        
//        m_Query.drawsBackground = false;
        [self addSubview:m_Query];

        auto views = NSDictionaryOfVariableBindings(m_Title, m_Query);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==21)-[m_Title]-[m_Query]-(==10)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[m_Query]|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[m_Title]|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];


//        return v;
    
    }
    return self;
}

static OSStatus CarbonCallback(EventHandlerCallRef inHandlerCallRef,
                               EventRef inEvent,
                               void *inUserData)
{
//    cout << "***" << endl;
    bool processed = [((__bridge FilterPopUpMenuItem*)inUserData) processInterceptedEvent:inEvent];
    
    if( !processed )
        return CallNextEventHandler( inHandlerCallRef, inEvent );
    else
        return noErr;
}

- (bool) processInterceptedEvent:(EventRef)_event
{
    const auto first_responder = self.window.firstResponder;
    if( first_responder == m_Query || first_responder == m_Query.currentEditor )
        return false;
    
//                NSText *fieldEditor = [parentTextField currentEditor];
//                if (hitView != parentTextField && (fieldEditor && hitView != fieldEditor) ) {
    

    const auto ev = [NSEvent eventWithEventRef:_event];
    if( !ev )
        return false;
    
    if( ev.type != NSEventTypeKeyDown )
        return false;

    const auto kc = ev.keyCode;
    if(
       kc == 115 || // home
       kc == 117 || // delete
       kc == 116 || // pgup
       kc == 119 || // end
       kc == 121 || // pgdn
       kc == 123 || // left
       kc == 124 || // right
       kc == 125 || // down
       kc == 126 || // up
       kc == 49  || // space
       kc == 36  || // return
       kc == 48     // tab
       
       )
        return false;
    
    const auto query = m_Query.stringValue;
    
    if( kc == 51 ) { // backspace
        if( query.length > 0 )
            [self setQuery:[query substringToIndex:query.length-1]];
        return true;
    }
    
//    if( kc == 48 ) { // tab
//        [self.window makeFirstResponder:self.window];
//        return true;
//    }
    
    
    NSString *chars = ev.charactersIgnoringModifiers;
    if( !chars || chars.length != 1 )
        return false;
    

    [self setQuery:[query stringByAppendingString:chars]];
    
//    m_Query.stringValue = [m_Query.stringValue stringByAppendingString:chars];
//
//    
//    [NSRunLoop.currentRunLoop performSelector:@selector(fireNotification)
//                                       target:self
//                                     argument:nil
//                                        order:0
//                                        modes:@[NSEventTrackingRunLoopMode]];
//    
    NSLog(@"%@", ev);

    return true;
}

- (void) setQuery:(NSString*)_query
{
    if( [_query isEqualToString:m_Query.stringValue] )
        return;
 
    m_Query.stringValue = _query;
    [NSRunLoop.currentRunLoop performSelector:@selector(fireNotification)
                                       target:self
                                     argument:nil
                                        order:0
                                        modes:@[NSEventTrackingRunLoopMode]];
}

- (void) viewDidMoveToWindow
{
    const auto window = self.window;
    if( window ) {
        if( ![window.className isEqualToString:@"NSCarbonMenuWindow"] ) {
            NSLog(@"Sorry, but FilterPopUpMenu was designed to work with NSCarbonMenuWindow.");
            return;
        }
        
        EventTypeSpec evts[2];
        evts[0].eventClass = kEventClassKeyboard;
        evts[0].eventKind = kEventRawKeyDown;
        evts[1].eventClass = kEventClassKeyboard;
        evts[1].eventKind = kEventRawKeyRepeat;

        const auto dispatcher = GetEventDispatcherTarget();
        if( !dispatcher )
            return;
        
        const auto result = InstallEventHandler(dispatcher,
                                                CarbonCallback,
                                                2,
                                                &evts[0],
                                                (__bridge void*)self,
                                                &m_EventHandler);
        if( result != noErr ) {
            NSLog(@"InstallEventHandler failed");
        }
    }
    else {
        if( m_EventHandler != nullptr ) {
            RemoveEventHandler(m_EventHandler);
            m_EventHandler = nullptr;
        }
    }
}

- (void)fireNotification
{
    if( NSMenuItem *item = self.enclosingMenuItem )
        if( NSMenu *menu = item.menu )
            if( auto filter_menu = objc_cast<FilterPopUpMenu>(menu) )
                [filter_menu updateFilter:m_Query.stringValue];
}

- (void)controlTextDidChange:(NSNotification *)obj;
{
//    NSTextField *tf = obj.object;
//    if( !tf )
//        return;
//    if( auto rv = objc_cast<NSTableRowView>(tf.superview) )
//        if( rv.superview == self.table ) {
//            long row_no = [self.table rowForView:rv];
//            if( row_no >= 0 && row_no < m_Favorites.size() ) {
//                auto new_value = tf.stringValue ? tf.stringValue.UTF8String : "";
//                if( m_Favorites[row_no].title != new_value ) {
//                    m_Favorites[row_no].title = new_value;
//                    [self commit];
//                }
//            }
//        }
//    NSLog( @"%@", m_TextField.stringValue );
    [self fireNotification];
}

//- (void)fixFirstResponder
//{
//    [self.window makeFirstResponder:m_TextField];
//}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    int a = 10;
    if( commandSelector == @selector(insertTab:) ) {
        [self.window makeFirstResponder:self.window];
        return true;
    }
//        cout << "!!" << endl;
////        [m_InitialFirstResponder moveDown:nil];
//
//        [m_InitialFirstResponder keyDown:[NSApp currentEvent]];
////        [self.window makeFirstResponder:m_TextField];
//        
////            [NSRunLoop.currentRunLoop performSelector:@selector(fixFirstResponder)
////                                       target:self
////                                     argument:nil
////                                        order:0
////                                        modes:@[NSEventTrackingRunLoopMode]];
//        
//        return true;
//        
////        - (void)keyUp:(id)arg1;
////- (void)keyDown:(id)arg1;
//        
//    }
//    
//    
    return false;
}

@end
