#include <boost/container/static_vector.hpp>
#include "QuickSearch.h"
#include "PanelDataFilter.h"
#include "PanelData.h"
#include "PanelView.h"
#include "PanelViewHeader.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include "CursorBackup.h"

using namespace nc::panel;
using namespace nc::panel::QuickSearch;

namespace nc::panel::QuickSearch {

static const nanoseconds g_SoftFilteringTimeout = 4s;

static KeyModif KeyModifFromInt(int _k);
static bool IsQuickSearchModifier(NSUInteger _modif, KeyModif _mode);
static bool IsQuickSearchStringCharacter(NSString *_s);
static bool IsLeft(NSString *_s);
static bool IsRight(NSString *_s);
static bool IsUp(NSString *_s);
static bool IsDown(NSString *_s);
static bool IsBackspace(NSString *_s);
static bool IsSpace(NSString *_s);
static NSString *RemoveLastCharacterWithNormalization(NSString *_s);
static NSString *ModifyStringByKeyDownString(NSString *_str, NSString *_key);
    
}

@implementation NCPanelQuickSearch
{
    PanelView                              *m_View;
    data::Model                            *m_Data;
    bool                                    m_IsSoftFiltering;
    bool                                    m_ShowTyping;
    int                                     m_SoftFilteringOffset;
    nanoseconds                             m_SoftFilteringLastAction;
    KeyModif                                m_Modifier;
    data::TextualFilter::Where              m_WhereToSearch;
    GenericConfig                          *m_Config;
    boost::container::static_vector<
        GenericConfig::ObservationTicket,4> m_ConfigObservers;
    
}

- (instancetype)initWithView:(PanelView*)_view
                        data:(nc::panel::data::Model&)_data
                      config:(GenericConfig&)_config
{
    if( !(self = [super init]) )
        return nil;
    m_View = _view;
    m_Data = &_data;
    m_Config = &_config;
    
    __weak NCPanelQuickSearch *weak_self = self;
    auto callback = [weak_self](NSString *_request){
        if( NCPanelQuickSearch *strong_self = weak_self  )
            strong_self.searchCriteria = _request;
    };
    _view.headerView.searchRequestChangeCallback = move(callback);

    // wire up config changing notifications
    auto add_co = [&](const char *_path, SEL _sel) { m_ConfigObservers.
        emplace_back( m_Config->Observe(_path, objc_callback(self, _sel)) );
    };
    add_co(g_ConfigWhereToFind,     @selector(configQuickSearchSettingsChanged) );
    add_co(g_ConfigIsSoftFiltering, @selector(configQuickSearchSettingsChanged) );
    add_co(g_ConfigTypingView,      @selector(configQuickSearchSettingsChanged) );
    add_co(g_ConfigKeyOption,       @selector(configQuickSearchSettingsChanged) );
    
    [self configQuickSearchSettingsChanged];
    
    return self;
}

- (void)configQuickSearchSettingsChanged
{
    m_WhereToSearch = data::TextualFilter::WhereFromInt( m_Config->GetInt(g_ConfigWhereToFind) );
    m_IsSoftFiltering = m_Config->GetBool( g_ConfigIsSoftFiltering );
    m_ShowTyping = m_Config->GetBool( g_ConfigTypingView );
    m_Modifier = KeyModifFromInt( m_Config->GetInt(g_ConfigKeyOption) );
    [self discardFiltering];
}

- (void)setSearchCriteria:(NSString*)_request
{
    if( _request == nil ) {
        [self discardFiltering];
        return;
    }
    
    if( m_IsSoftFiltering )
        [self setSoftFiltering:_request];
    else
        [self setHardFiltering:_request];
}

- (NSString*)searchCriteria
{
    if( m_IsSoftFiltering )
        return m_Data->SoftFiltering().text;
    else
        return m_Data->HardFiltering().text.text;
}

- (void)discardFiltering
{
    CursorBackup pers(m_View, *m_Data);
    const auto any_changed = m_Data->ClearTextFiltering();
    [self setPanelHeaderPrompt:nil withMatchesCount:0];
    
    if( any_changed ) {
        [m_View dataUpdated];
        if( pers.IsValid() )
            pers.Restore();
        else
            m_View.curpos = m_Data->SortedEntriesCount() > 0 ? 0 : -1;
    }
}

- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view
{
    const auto modif = _event.modifierFlags;
    if( !IsQuickSearchModifier(modif, m_Modifier) )
        return view::BiddingPriority::Skip;
    
    const auto character = _event.charactersIgnoringModifiers;
    if( character.length == 0 )
        return view::BiddingPriority::Skip;

    if( IsQuickSearchStringCharacter(character) )
        return view::BiddingPriority::Default;
    
    bool empty_now = m_IsSoftFiltering ?
        m_Data->SoftFiltering().text.length == 0 :
        m_Data->HardFiltering().text.text.length == 0;

    if( !empty_now ) {
        if( IsSpace(character) )
            return view::BiddingPriority::Default;
        if( IsBackspace(character) )
            return view::BiddingPriority::Default;
        if( m_IsSoftFiltering ) {
            if( IsLeft(character) || IsRight(character) || IsUp(character) || IsDown(character) )
                return view::BiddingPriority::Default;
        }
        if( _event.keyCode == 53 ) { // Esc button
            return view::BiddingPriority::Default;;
        }
    }
    
    return view::BiddingPriority::Skip;
}

- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view
{
    if( _event.keyCode == 53 ) { // Esc button
        [self setSearchCriteria:nil];
        return;
    }
    
    if( m_IsSoftFiltering  )
        [self eatKeydownForSoftFiltering:_event];
    else
        [self eatKeydownForHardFiltering:_event];
}

- (void)eatKeydownForHardFiltering:(NSEvent *)_event
{
    const auto key = _event.charactersIgnoringModifiers.decomposedStringWithCanonicalMapping;
    const auto current = m_Data->HardFiltering().text.text;
    const auto replace = ModifyStringByKeyDownString(current, key);
    
    if( replace == nil || replace.length == 0 ) {
        [self discardFiltering];
        return;
    }
    
    [self setHardFiltering:replace];
}

- (void)eatKeydownForSoftFiltering:(NSEvent *)_event
{
    const auto key = _event.charactersIgnoringModifiers.decomposedStringWithCanonicalMapping;
    if( IsDown(key) ) {
        [self moveToNextSoftFilteredItem];
        return;
    }
    if( IsUp(key) ) {
        [self moveToPreviousSoftFilteredItem];
        return;
    }
    if( IsLeft(key) ) {
        [self moveToFirstSoftFilteredItem];
        return;
    }
    if( IsRight(key) ) {
        [self moveToLastSoftFilteredItem];
        return;
    }
    
    const auto is_in_progress = m_SoftFilteringLastAction + g_SoftFilteringTimeout >= machtime();
    const auto current = is_in_progress ? m_Data->SoftFiltering().text : (NSString*)nil;
    const auto replace = ModifyStringByKeyDownString(current, key);
    
    if( replace == nil || replace.length == 0 ) {
        [self discardFiltering];
        return;
    }
    
    [self setSoftFiltering:replace];
}

- (void)setHardFiltering:(NSString*)_text
{
    auto filtering = m_Data->HardFiltering();
    if( filtering.text.text == _text ||
        [filtering.text.text isEqualToString:_text] )
        return;
    
    filtering.text.text = _text;
    if( filtering.text.text == nil )
        return;

    CursorBackup pers(m_View, *m_Data);

    filtering.text.type = m_WhereToSearch;
    filtering.text.clear_on_new_listing = true;
    filtering.text.hightlight_results = m_ShowTyping;
    m_Data->SetHardFiltering(filtering);

    pers.Restore();

    [m_View dataUpdated];
    [self updateTypingUIForHardFiltering];

    // for convinience - if we have ".." and cursor is on it - move it to the first element after
    if(m_View.curpos == 0 &&
       m_Data->SortedDirectoryEntries().size() >= 2 &&
       m_Data->EntryAtRawPosition(m_Data->SortedDirectoryEntries()[0]).IsDotDot() )
        m_View.curpos = 1;
}


- (void)setSoftFiltering:(NSString*)_text
{
    if( !_text )
        return;
    
    const auto current_time = machtime();
    
    auto filtering = m_Data->SoftFiltering();
    if( m_SoftFilteringLastAction + g_SoftFilteringTimeout < current_time )
        m_SoftFilteringOffset = 0;
    
    filtering.text = _text;
    filtering.type = m_WhereToSearch;
    filtering.ignore_dot_dot = false;
    filtering.hightlight_results = m_ShowTyping;
    m_Data->SetSoftFiltering(filtering);
    
    m_SoftFilteringLastAction = current_time;
    
    const auto filtered_amount = (int)m_Data->EntriesBySoftFiltering().size();
    
    if( filtered_amount != 0 ) {
        if( m_SoftFilteringOffset >= filtered_amount )
            m_SoftFilteringOffset = filtered_amount - 1;
        m_View.curpos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
    }
    
    if( m_ShowTyping ) {
        [self setPanelHeaderPrompt:m_Data->SoftFiltering().text
                  withMatchesCount:filtered_amount];
        [m_View volatileDataChanged];
    }
    
    [self scheduleSoftFilteringCleanup];
    
}

- (void)moveToFirstSoftFilteredItem
{
    const auto filtered_amount = (int)m_Data->EntriesBySoftFiltering().size();
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = 0;
        m_View.curpos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        m_SoftFilteringLastAction = machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)moveToLastSoftFilteredItem
{
    const auto filtered_amount = (int)m_Data->EntriesBySoftFiltering().size();
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = filtered_amount - 1;
        m_View.curpos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        m_SoftFilteringLastAction = machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)moveToPreviousSoftFilteredItem
{
    const auto filtered_amount = (int)m_Data->EntriesBySoftFiltering().size();
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = max( 0, m_SoftFilteringOffset - 1 );
        m_View.curpos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        m_SoftFilteringLastAction = machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)moveToNextSoftFilteredItem
{
    const auto filtered_amount = (int)m_Data->EntriesBySoftFiltering().size();
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = min( filtered_amount - 1, m_SoftFilteringOffset + 1 );
        m_View.curpos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        m_SoftFilteringLastAction = machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)scheduleSoftFilteringCleanup
{
    __weak NCPanelQuickSearch *weak_self = self;
    auto clear_filtering = [=]{
        if( NCPanelQuickSearch *strong_self = weak_self ) {
            if( strong_self->m_SoftFilteringLastAction + g_SoftFilteringTimeout <= machtime() )
                [strong_self setSearchCriteria:nil];
        }
    };
    
    dispatch_to_main_queue_after( g_SoftFilteringTimeout + 1000ns, move(clear_filtering) );
}

- (void)updateTypingUIForHardFiltering
{
    if( !m_ShowTyping )
        return;
    
    auto filtering = m_Data->HardFiltering();
    if(!filtering.text.text) {
        [self setPanelHeaderPrompt:nil withMatchesCount:0];
    }
    else {
        int total = (int)m_Data->SortedDirectoryEntries().size();
        if(total > 0 && m_Data->Listing().IsDotDot(0))
            total--;
        [self setPanelHeaderPrompt:filtering.text.text withMatchesCount:total];
    }
}

- (void) setPanelHeaderPrompt:(NSString*)_text withMatchesCount:(int)_count
{
    m_View.headerView.searchPrompt = _text;
    m_View.headerView.searchMatches = _count;
}

@end

namespace nc::panel::QuickSearch {

static bool IsQuickSearchModifier(NSUInteger _modif, KeyModif _mode)
{
    // we don't care about CapsLock, Function or NumPad
    _modif &= ~(NSAlphaShiftKeyMask | NSFunctionKeyMask | NSEventModifierFlagNumericPad ) &
                (NSDeviceIndependentModifierFlagsMask);
 
    const auto alt = NSAlternateKeyMask;
    const auto shift = NSShiftKeyMask;
    const auto ctrl = NSControlKeyMask;
        
    switch (_mode) {
        case KeyModif::WithAlt:
            return _modif == alt || _modif == (alt|shift);
        case KeyModif::WithCtrlAlt:
            return _modif == (alt|ctrl) || _modif == (alt|ctrl|shift);
        case KeyModif::WithShiftAlt:
            return _modif == (alt|shift);
        case KeyModif::WithoutModif:
            return _modif == 0 || _modif == shift;
        default:
            break;
    }
    return false;
}

static bool IsQuickSearchStringCharacter(NSString *_s)
{
    static const auto chars = []{
        auto set = [NSMutableCharacterSet new];
        [set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];

        // such character simply can't appear in filename under unix
        [set removeCharactersInString:@"/"];
        return (NSCharacterSet*)set;
    }();
    
    if( _s.length == 0 )
        return false;
    const auto u = [_s characterAtIndex:0]; // consider uing UTF-32 here ?
    return [chars characterIsMember:u];
}

static bool IsBackspace(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == NSDeleteCharacter;
}

static bool IsSpace(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0x20;
}
    
static bool IsLeft(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0xF702;
}
    
static bool IsRight(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0xF703;
}
    
static bool IsUp(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0xF700;
}
    
static bool IsDown(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0xF701;
}

static NSString *RemoveLastCharacterWithNormalization(NSString *_s)
{
    // remove last symbol. since strings are decomposed (as for file system interaction),
    // it should be composed first and decomposed back after altering
    assert(_s != nil);
    assert(_s.length > 0);
    NSString *s = _s.precomposedStringWithCanonicalMapping;
    s = [s substringToIndex:s.length-1];
    return s.decomposedStringWithCanonicalMapping;
}

static NSString *ModifyStringByKeyDownString(NSString *_str, NSString *_key)
{
    if( !_key )
        return _str;
    
    if( !IsBackspace(_key) )
        _str = _str ? [_str stringByAppendingString:_key] : _key;
    else
        _str = _str.length > 0 ? RemoveLastCharacterWithNormalization(_str) : nil;
    
    return _str;
}
    
static KeyModif KeyModifFromInt(int _k)
{
    if(_k >= 0 && _k <= (int)KeyModif::Disabled)
        return (KeyModif)_k;
    return KeyModif::WithAlt;
}

}
