// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
    NSString           *m_Filter;
    vector<NSString*>   m_KeyEquivalents;
    bool                m_KeyEquivalentsHidden;
}

- (instancetype)init
{
    return [self initWithTitle:@""];
}

- (instancetype)initWithTitle:(NSString *)_title
{
    self = [super initWithTitle:_title];
    if( self ) {
        m_KeyEquivalentsHidden = false;
    
        auto header_view = [[FilterPopUpMenuItem alloc] initWithFrame:NSMakeRect(0, 0, 220, 21)];
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

    [self updateEquivalents];
    
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

- (void) updateEquivalents
{
    if( m_KeyEquivalents.empty() )
        for( NSMenuItem *i in self.itemArray )
            m_KeyEquivalents.emplace_back(i.keyEquivalent);

    if( m_Filter.length == 0 && m_KeyEquivalentsHidden == true ) {
        auto items = self.itemArray;
        for( int i1 = 0, e1 = (int)items.count, i2 = 0, e2 = (int)m_KeyEquivalents.size();
            i1 != e1 && i2 != e2;
            ++i1, ++i2)
            [items objectAtIndex:i1].keyEquivalent = m_KeyEquivalents[i2];
        m_KeyEquivalentsHidden = false;
    }
    else if( m_Filter.length != 0 && m_KeyEquivalentsHidden == false ) {
        for( NSMenuItem *i in self.itemArray )
            i.keyEquivalent = @"";
        m_KeyEquivalentsHidden = true;
    }
}

- (void) higlightCustomItem:(NSMenuItem*)_item
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
        m_Title.font = [NSFont menuFontOfSize:13];
        m_Title.textColor = NSColor.tertiaryLabelColor;
        [self addSubview:m_Title];

        m_Query = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        m_Query.translatesAutoresizingMaskIntoConstraints = false;
        m_Query.stringValue = @"";
        m_Query.editable = true;
        m_Query.enabled = true;
        m_Query.usesSingleLineMode = true;
        m_Query.lineBreakMode = NSLineBreakByTruncatingHead;
        m_Query.delegate = self;
        m_Query.bordered = true;
        m_Query.bezeled = true;
        m_Query.bezelStyle = NSTextFieldRoundedBezel;
        m_Query.font = [NSFont menuFontOfSize:13];
        m_Query.hidden = true;
        [self addSubview:m_Query];

        auto views = NSDictionaryOfVariableBindings(m_Title, m_Query);
        [self addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"|-(==21)-[m_Title]-[m_Query]-(==10)-|"
                              options:0
                              metrics:nil
                              views:views]];
        [self addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"V:|[m_Query]-(==1)-|"
                              options:0
                              metrics:nil
                              views:views]];
        [self addConstraints:[NSLayoutConstraint
            constraintsWithVisualFormat:@"V:|[m_Title]-(==1)-|"
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

    const auto menu_item = (__bridge FilterPopUpMenuItem*)_user_data;
    if( ![menu_item processInterceptedEvent:_event] )
        return CallNextEventHandler( _handler, _event );
    else
        return noErr;
}

static const vector<bool> g_PassthruTable = []{
    vector<bool> table(256, false);
    table[115] = true; // Home
    table[117] = true; // Delete
    table[116] = true; // PgUp
    table[119] = true; // End
    table[121] = true; // PgDn
    table[123] = true; // Left
    table[124] = true; // Right
    table[125] = true; // Down
    table[126] = true; // Up
    table[49 ] = true; // Space
    table[36 ] = true; // Return
    table[53 ] = true; // Esc
    table[71 ] = true; // Clear
    table[76 ] = true; // Insert
    table[48 ] = true; // Tab
    table[114] = true; // Help
    table[122] = true; // F1
    table[120] = true; // F2
    table[99 ] = true; // F3
    table[118] = true; // F4
    table[96 ] = true; // F5
    table[97 ] = true; // F6
    table[98 ] = true; // F7
    table[100] = true; // F8
    table[101] = true; // F9
    table[109] = true; // F10
    table[103] = true; // F11
    table[111] = true; // F12
    table[105] = true; // F13
    table[107] = true; // F14
    table[113] = true; // F15
    table[106] = true; // F16
    table[64 ] = true; // F17
    table[79 ] = true; // F18
    table[80 ] = true; // F19
    return table;
}();

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
    if( kc >= g_PassthruTable.size() || g_PassthruTable[kc] )
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
    [self updateVisibility];
}

- (void) viewDidMoveToWindow
{
    const auto window = self.window;
    if( window ) {
        if( ![window.className isEqualToString:@"NSCarbonMenuWindow"] ) {
            NSLog(@"Sorry, but FilterPopUpMenu was designed to work with NSCarbonMenuWindow.");
            return;
        }
        
        const auto dispatcher = GetEventDispatcherTarget();
        if( !dispatcher ) {
            NSLog(@"GetEventDispatcherTarget() failed");
            return;
        }
        
        EventTypeSpec evts[2];
        evts[0].eventClass = kEventClassKeyboard;
        evts[0].eventKind = kEventRawKeyDown;
        evts[1].eventClass = kEventClassKeyboard;
        evts[1].eventKind = kEventRawKeyRepeat;
        const auto result = InstallEventHandler(dispatcher,
                                                CarbonCallback,
                                                2,
                                                &evts[0],
                                                (__bridge void*)self,
                                                &m_EventHandler);
        if( result != noErr ) {
            NSLog(@"InstallEventHandler() failed");
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

- (void) updateVisibility
{
    m_Query.hidden = m_Query.stringValue.length == 0;
}

- (void)controlTextDidChange:(NSNotification *)obj;
{
    [self updateVisibility];
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
