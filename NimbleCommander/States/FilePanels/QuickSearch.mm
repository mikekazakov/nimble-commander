#include "QuickSearch.h"
#include "PanelDataFilter.h"
#include "PanelData.h"
#include "PanelView.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include "CursorBackup.h"

using namespace nc::panel;
using namespace nc::panel::QuickSearch;

namespace nc::panel::QuickSearch {

static const nanoseconds g_SoftFilteringTimeout = 4s;

static KeyModif KeyModifFromInt(int _k);
static bool IsQuickSearchModifier(NSUInteger _modif, KeyModif _mode);
static bool IsQuickSearchStringCharacter(NSString *_s);
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
    vector<GenericConfig::ObservationTicket>m_ConfigObservers;
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

    // wire up config changing notifications
    auto add_co = [&](const char *_path, SEL _sel) { m_ConfigObservers.
        emplace_back( m_Config->Observe(_path, objc_callback(self, _sel)) );
    };
    add_co(g_ConfigWhereToFind,  @selector(configQuickSearchSettingsChanged) );
    add_co(g_ConfigIsSoftFiltering,@selector(configQuickSearchSettingsChanged) );
    add_co(g_ConfigTypingView,   @selector(configQuickSearchSettingsChanged) );
    add_co(g_ConfigKeyOption,    @selector(configQuickSearchSettingsChanged) );
    
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
    [m_View setQuickSearchPrompt:nil withMatchesCount:0];
    
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

    if( !empty_now && IsSpace(character) )
        return view::BiddingPriority::Default;
    if( !empty_now && IsBackspace(character) )
        return view::BiddingPriority::Default;
    
    
        
    
    //    if( IsQuickSearchModifier(modif, m_QuickSearchMode) &&
    //       ( IsQuickSearchStringCharacter(character) ||
    //        ( !empty_text && IsSpace(character) ) ||
    //        IsBackspace(character)
    //        )
    //       ) {
    //        if(m_QuickSearchIsSoftFiltering)
    //            return [self HandleQuickSearchSoft:character.decomposedStringWithCanonicalMapping];
    //        else
    //            return [self HandleQuickSearchHard:character.decomposedStringWithCanonicalMapping];
    //    }
    
    
    
//
//    if( IsQuickSearchModifier(modif, m_QuickSearchMode) &&
//       ( IsQuickSearchStringCharacter(character) ||
//        ( !empty_text && IsSpace(character) ) ||
//        IsBackspace(character)
//        )
//       ) {
//        if(m_QuickSearchIsSoftFiltering)
//            return [self HandleQuickSearchSoft:character.decomposedStringWithCanonicalMapping];
//        else
//            return [self HandleQuickSearchHard:character.decomposedStringWithCanonicalMapping];
//    }
    
    
//    else if( character.length == 1 )
//        switch([character characterAtIndex:0]) {
//            case NSUpArrowFunctionKey:
//                if( IsQuickSearchModifierForArrows(modif, m_QuickSearchMode) ) {
//                    [self QuickSearchPrevious];
//                    return true;
//                }
//            case NSDownArrowFunctionKey:
//                if( IsQuickSearchModifierForArrows(modif, m_QuickSearchMode) ) {
//                    [self QuickSearchNext];
//                    return true;
//                }
//        }
//    
//    return false;

    
    
    
    
    return view::BiddingPriority::Skip;
}

- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view
{
    if( m_IsSoftFiltering  )
        [self eatKeydownForSoftFiltering:_event];
    else
        [self eatKeydownForHardFiltering:_event];
}

/*
- (bool)HandleQuickSearchHard:(NSString*) _key
{
    NSString *text = m_Data.HardFiltering().text.text;
    
    text = ModifyStringByKeyDownString(text, _key);
    if( text == nil )
        return false;
    
    if( text.length == 0 ) {
        [self clearQuickSearchFiltering];
        return true;
    }
    
    [self SetQuickSearchHard:text];
    
    return true;
}
*/

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

    // for convinience - if we have ".." and cursor is on it - move it to first element (if any)
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
        [m_View setQuickSearchPrompt:m_Data->SoftFiltering().text
                    withMatchesCount:filtered_amount];
        
        // automatically remove prompt after g_FastSeachDelayTresh
        __weak NCPanelQuickSearch *weak_self = self;
        auto clear_filtering = [=]{
            if( NCPanelQuickSearch *strong_self = weak_self ) {
                if( strong_self->m_SoftFilteringLastAction + g_SoftFilteringTimeout <= machtime() )
                    [strong_self setSearchCriteria:nil];
            }
        };
        
        dispatch_to_main_queue_after( g_SoftFilteringTimeout + 1000ns, move(clear_filtering) );
        [m_View volatileDataChanged];
    }
}

- (void)updateTypingUIForHardFiltering
{
    if( !m_ShowTyping )
        return;
    
    auto filtering = m_Data->HardFiltering();
    if(!filtering.text.text) {
        [m_View setQuickSearchPrompt:nil withMatchesCount:0];
    }
    else {
        int total = (int)m_Data->SortedDirectoryEntries().size();
        if(total > 0 && m_Data->Listing().IsDotDot(0))
            total--;
        [m_View setQuickSearchPrompt:filtering.text.text withMatchesCount:total];
    }
}

/*

 
- (bool)HandleQuickSearchSoft: (NSString*) _key
{
    nanoseconds currenttime = machtime();
    
    // update soft filtering
    NSString *text = m_Data.SoftFiltering().text;
    if( m_QuickSearchLastType + g_FastSeachDelayTresh < currenttime )
        text = nil;
    
    text = ModifyStringByKeyDownString(text, _key);
    if( !text  )
        return false;
    
    if( text.length == 0 ) {
        [self clearQuickSearchFiltering];
        return true;
    }
    
    [self SetQuickSearchSoft:text];
    
    return true;
}

- (void)SetQuickSearchSoft:(NSString*) _text
{
    if( !_text )
        return;
    
    nanoseconds currenttime = machtime();
    
    // update soft filtering
    auto filtering = m_Data.SoftFiltering();
    if( m_QuickSearchLastType + g_FastSeachDelayTresh < currenttime )
        m_QuickSearchOffset = 0;
    
    filtering.text = _text;
    filtering.type = m_QuickSearchWhere;
    filtering.ignore_dot_dot = false;
    filtering.hightlight_results = m_QuickSearchTypingView;
    m_Data.SetSoftFiltering(filtering);
    
    m_QuickSearchLastType = currenttime;
    
    if( !m_Data.EntriesBySoftFiltering().empty() ) {
        if(m_QuickSearchOffset >= m_Data.EntriesBySoftFiltering().size())
            m_QuickSearchOffset = (unsigned)m_Data.EntriesBySoftFiltering().size() - 1;
        m_View.curpos = m_Data.EntriesBySoftFiltering()[m_QuickSearchOffset];
    }
    
    if( m_QuickSearchTypingView ) {
        int total = (int)m_Data.EntriesBySoftFiltering().size();
        [m_View setQuickSearchPrompt:m_Data.SoftFiltering().text withMatchesCount:total];
        //        m_View.quickSearchPrompt = PromptForMatchesAndString(total, m_Data.SoftFiltering().text);
        
        // automatically remove prompt after g_FastSeachDelayTresh
        __weak PanelController *wself = self;
        dispatch_to_main_queue_after(g_FastSeachDelayTresh + 1000ns, [=]{
            if(PanelController *sself = wself)
                if( sself->m_QuickSearchLastType + g_FastSeachDelayTresh <= machtime() )
                    [sself clearQuickSearchFiltering];
        });
        
        [m_View volatileDataChanged];
    }
}



- (void) QuickSearchSetCriteria:(NSString *)_text
{
    if( m_QuickSearchIsSoftFiltering )
        [self SetQuickSearchSoft:_text];
    else
        [self SetQuickSearchHard:_text];
}

- (void)QuickSearchPrevious
{
    if(m_QuickSearchOffset > 0)
        m_QuickSearchOffset--;
    [self HandleQuickSearchSoft:nil];
}

- (void)QuickSearchNext
{
    m_QuickSearchOffset++;
    [self HandleQuickSearchSoft:nil];
}

- (bool) QuickSearchProcessKeyDown:(NSEvent *)event
{
    NSString*  const character   = [event charactersIgnoringModifiers];
    NSUInteger const modif       = [event modifierFlags];
    
    bool empty_text = m_QuickSearchIsSoftFiltering ?
    m_Data.SoftFiltering().text.length == 0 :
    m_Data.HardFiltering().text.text.length == 0;
    
    if( IsQuickSearchModifier(modif, m_QuickSearchMode) &&
       ( IsQuickSearchStringCharacter(character) ||
        ( !empty_text && IsSpace(character) ) ||
        IsBackspace(character)
        )
       ) {
        if(m_QuickSearchIsSoftFiltering)
            return [self HandleQuickSearchSoft:character.decomposedStringWithCanonicalMapping];
        else
            return [self HandleQuickSearchHard:character.decomposedStringWithCanonicalMapping];
    }
    else if( character.length == 1 )
        switch([character characterAtIndex:0]) {
            case NSUpArrowFunctionKey:
                if( IsQuickSearchModifierForArrows(modif, m_QuickSearchMode) ) {
                    [self QuickSearchPrevious];
                    return true;
                }
            case NSDownArrowFunctionKey:
                if( IsQuickSearchModifierForArrows(modif, m_QuickSearchMode) ) {
                    [self QuickSearchNext];
                    return true;
                }
        }
    
    return false;
}

- (void) QuickSearchUpdate
{
    if(!m_QuickSearchIsSoftFiltering)
        [self QuickSearchHardUpdateTypingUI];
}

*/

@end

namespace nc::panel::QuickSearch {

static bool IsQuickSearchModifier(NSUInteger _modif, KeyModif _mode)
{
    // exclude CapsLock from our decision process
    _modif &= (~NSAlphaShiftKeyMask) & (NSDeviceIndependentModifierFlagsMask);
 
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
    static NSCharacterSet *chars;
    static once_flag once;
    call_once(once, []{
        NSMutableCharacterSet *un = [NSMutableCharacterSet new];
        [un formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [un removeCharactersInString:@"/"]; // such character simply can't appear in filename under unix
        chars = un;
    });
    
    if(_s.length == 0)
        return false;
    
    unichar u = [_s characterAtIndex:0]; // consider uing UTF-32 here ?
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
