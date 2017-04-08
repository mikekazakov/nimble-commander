#include <Carbon/Carbon.h>
#include "FilterPopUpMenu.h"

@interface FilterPopUpMenu()

- (void) updateFilter:(NSString*)_filter;

@end

@interface FilterPopUpMenuItem : NSView<NSTextFieldDelegate>

@property (nonatomic) NSString *title;

@end

@implementation FilterPopUpMenu
{
    NSString *m_Filter;
}

- (instancetype)initWithTitle:(NSString *)_title
{
    self = [super initWithTitle:_title];
    if( self ) {
        auto header_view = [[FilterPopUpMenuItem alloc] initWithFrame:NSMakeRect(0, 0, 220, 20)];
        header_view.title = _title;
        
        auto header_item = [[NSMenuItem alloc] init];
        header_item.title = _title;
        header_item.view = header_view;
        [self addItem:header_item];
    }
    return self;
}

- (void) updateFilter:(NSString*)_filter
{
    m_Filter = _filter;
    auto items = self.itemArray;
    for( int i = 1, e = (int)items.count; i < e; ++i ) {
        auto item = [items objectAtIndex:i];
        item.hidden = ![self validateItem:item];
    }
    
    if( self.highlightedItem == nil || self.highlightedItem.hidden ) {
        
        NSMenuItem *item_to_highlight = nil;
        for( int i = 1, e = (int)items.count; i < e; ++i ) {
            auto item = [items objectAtIndex:i];
            if( !item.hidden && item.enabled ) {
                item_to_highlight = item;
                break;
            }
        }
        
        if( item_to_highlight )
            [self higlightCustomItem:item_to_highlight];
    }
}

- (bool) validateItem:(NSMenuItem*)_item
{
    if( !m_Filter || m_Filter.length == 0)
        return true;
    if( _item.isSeparatorItem || !_item.enabled )
        return false;
    
    return [_item.title rangeOfString:m_Filter
                              options:NSCaseInsensitiveSearch].length > 0;
}

- (void)higlightCustomItem:(NSMenuItem*)_item
{
    static const auto selHighlightItem = NSSelectorFromString(@"highlightItem:");
    if( [self respondsToSelector:selHighlightItem] ) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selHighlightItem withObject:_item];
#pragma clang diagnostic pop
    }
}

@end


@implementation FilterPopUpMenuItem
{
    NSTextField *m_Title;
    NSTextField *m_Query;
    EventHandlerRef m_EventHandler;
}

- (instancetype) initWithFrame:(NSRect)frameRect
{
    if( self = [super initWithFrame:frameRect]) {
        m_EventHandler = nullptr;
        self.autoresizingMask = NSViewWidthSizable;

        m_Title = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        m_Title.translatesAutoresizingMaskIntoConstraints = false;
        m_Title.stringValue = @"";
        m_Title.bordered = false;
        m_Title.editable = false;
        m_Title.enabled = false;
        m_Title.usesSingleLineMode = true;
        m_Title.drawsBackground = false;
        m_Title.font = [NSFont menuFontOfSize:14];
        m_Title.textColor = NSColor.tertiaryLabelColor;
        [self addSubview:m_Title];

        m_Query = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        m_Query.translatesAutoresizingMaskIntoConstraints = false;
        m_Query.stringValue = @"";
        m_Query.editable = true;
        m_Query.enabled = true;
        m_Query.usesSingleLineMode = true;
        m_Query.lineBreakMode = NSLineBreakByTruncatingHead;
        m_Query.placeholderString = @"Filter";
        m_Query.delegate = self;
        m_Query.bordered = true;
        m_Query.bezeled = true;
        m_Query.bezelStyle = NSTextFieldRoundedBezel;
        m_Query.font = [NSFont menuFontOfSize:0];
        [self addSubview:m_Query];

        auto views = NSDictionaryOfVariableBindings(m_Title, m_Query);
        [self addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"|-(==21)-[m_Title]-[m_Query]-(==10)-|"
                              options:0
                              metrics:nil
                              views:views]];
        [self addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"V:|[m_Query]|"
                              options:0
                              metrics:nil
                              views:views]];
        [self addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"V:|[m_Title]|"
                              options:0
                              metrics:nil
                              views:views]];
    }
    return self;
}

- (void) setTitle:(NSString *)title
{
    m_Title.stringValue = title;
}

- (NSString*)title
{
    return m_Title.stringValue;
}

static OSStatus CarbonCallback(EventHandlerCallRef _handler,
                               EventRef _event,
                               void *_user_data)
{
    if( !_event || !_user_data )
        return noErr;

    auto menu_item = (__bridge FilterPopUpMenuItem*)_user_data;
    
    if( ![menu_item processInterceptedEvent:_event] )
        return CallNextEventHandler( _handler, _event );
    else
        return noErr;
}

- (bool) processInterceptedEvent:(EventRef)_event
{
    const auto first_responder = self.window.firstResponder;
    if( first_responder == m_Query || first_responder == m_Query.currentEditor )
        return false;
    
    const auto ev = [NSEvent eventWithEventRef:_event];
    if( !ev )
        return false;
    
    if( ev.type != NSEventTypeKeyDown )
        return false;

    const auto kc = ev.keyCode;
    if( kc == 115 || // home
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
        kc == 53  || // esc
        kc == 71  || // clear
        kc == 76  || // insert
        kc == 48  || // tab
        kc == 114 || // Help
        kc == 122 || // F1
        kc == 120 || // F2
        kc == 99  || // F3
        kc == 118 || // F4
        kc == 96  || // F5
        kc == 97  || // F6
        kc == 98  || // F7
        kc == 100 || // F8
        kc == 101 || // F9
        kc == 109 || // F10
        kc == 103 || // F11
        kc == 111 || // F12
        kc == 105 || // F13
        kc == 107 || // F14
        kc == 113 || // F15
        kc == 106 || // F16
        kc == 64  || // F17
        kc == 79  || // F18
        kc == 80     // F19
       )
        return false;
    
    const auto mod_flags = ev.modifierFlags;
    if( (mod_flags & NSEventModifierFlagCommand) != 0 ||
        (mod_flags & NSEventModifierFlagControl) != 0 ||
        (mod_flags & NSEventModifierFlagOption)  != 0  )
        return false;
    
    const auto query = m_Query.stringValue;
    
    if( kc == 51 ) { // backspace
        if( query.length > 0 )
            [self setQuery:[query substringToIndex:query.length-1]];
        return true;
    }

    const auto chars = ev.charactersIgnoringModifiers;
    if( chars && chars.length == 1 ) {
        [self setQuery:[query stringByAppendingString:chars]];
        return true;
    }
    
//    NSLog(@"%@", ev);

    return false;
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
            NSLog(@"InstallEventHandler() failed");
        }

        [NSRunLoop.currentRunLoop performSelector:@selector(fireNotification)
                                           target:self
                                         argument:nil
                                            order:0
                                            modes:@[NSEventTrackingRunLoopMode]];
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
    [self fireNotification];
}

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)commandSelector
{
    if( commandSelector == @selector(insertTab:) ) {
        [self.window makeFirstResponder:self.window];
        return true;
    }
    return false;
}

@end
