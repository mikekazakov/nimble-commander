// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QuickSearch.h"
#include <Panel/PanelDataFilter.h>
#include <Panel/PanelData.h>
#include <Panel/CursorBackup.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Base/mach_time.h>
#include <array>

using namespace nc::panel;
using namespace nc::panel::QuickSearch;
using namespace std::literals;

namespace nc::panel::QuickSearch {

static const std::chrono::nanoseconds g_SoftFilteringTimeout = std::chrono::seconds{4};

static KeyModif KeyModifFromInt(int _k);
static bool IsQuickSearchModifier(NSUInteger _modif, KeyModif _mode);
static bool IsQuickSearchStringCharacter(NSString *_s);
static bool IsLeft(NSString *_s);
static bool IsRight(NSString *_s);
static bool IsUp(NSString *_s);
static bool IsDown(NSString *_s);
static bool IsBackspace(NSString *_s);
static NSString *RemoveLastCharacterWithNormalization(NSString *_s);
static NSString *ModifyStringByKeyDownString(NSString *_str, NSString *_key);

} // namespace nc::panel::QuickSearch

@implementation NCPanelQuickSearch {
    __weak NSObject<NCPanelQuickSearchDelegate> *m_Delegate;
    data::Model *m_Data;
    bool m_IsSoftFiltering;
    bool m_ShowTyping;
    int m_SoftFilteringOffset;
    std::chrono::nanoseconds m_SoftFilteringLastAction;
    KeyModif m_Modifier;
    data::TextualFilter::Where m_WhereToSearch;
    nc::config::Config *m_Config;
    std::array<nc::config::Token, 5> m_ConfigObservers;
    NSCharacterSet *m_IgnoreCharacters;
}

- (instancetype)initWithData:(nc::panel::data::Model &)_data
                    delegate:(NSObject<NCPanelQuickSearchDelegate> *)_delegate
                      config:(nc::config::Config &)_config
{
    self = [super init];
    if( !self )
        return nil;
    m_Delegate = _delegate;
    m_Data = &_data;
    m_Config = &_config;

    // wire up config changing notifications
    auto wire = [&](std::string_view _path) {
        auto sel = @selector(configQuickSearchSettingsChanged);
        return m_Config->Observe(_path, nc::objc_callback_to_main_queue(self, sel));
    };
    m_ConfigObservers[0] = wire(g_ConfigWhereToFind);
    m_ConfigObservers[1] = wire(g_ConfigIsSoftFiltering);
    m_ConfigObservers[2] = wire(g_ConfigTypingView);
    m_ConfigObservers[3] = wire(g_ConfigKeyOption);
    m_ConfigObservers[4] = wire(g_ConfigIgnoreCharacters);
    [self configQuickSearchSettingsChanged];

    return self;
}

- (void)configQuickSearchSettingsChanged
{
    m_WhereToSearch = data::TextualFilter::WhereFromInt(m_Config->GetInt(g_ConfigWhereToFind));
    m_IsSoftFiltering = m_Config->GetBool(g_ConfigIsSoftFiltering);
    m_ShowTyping = m_Config->GetBool(g_ConfigTypingView);
    m_Modifier = KeyModifFromInt(m_Config->GetInt(g_ConfigKeyOption));
    [self rebuildIgnoreCharacters];
    [self discardFiltering];
}

- (void)rebuildIgnoreCharacters
{
    auto set = [NSMutableCharacterSet new];
    auto chars = [NSString stringWithUTF8StdString:m_Config->GetString(g_ConfigIgnoreCharacters)];
    [set addCharactersInString:[chars lowercaseString]];
    [set addCharactersInString:[chars uppercaseString]];
    m_IgnoreCharacters = set;
}

- (void)setSearchCriteria:(NSString *)_request
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

- (NSString *)searchCriteria
{
    if( m_IsSoftFiltering )
        return m_Data->SoftFiltering().text;
    else
        return m_Data->HardFiltering().text.text;
}

- (void)discardFiltering
{
    const auto pers = CursorBackup{[m_Delegate quickSearchNeedsCursorPosition:self], *m_Data};
    const auto any_changed = m_Data->ClearTextFiltering();
    [self setPanelHeaderPrompt:nil withMatchesCount:0];
    if( any_changed ) {
        [m_Delegate quickSearchHasUpdatedData:self];
        [m_Delegate quickSearch:self wantsToSetCursorPosition:pers.RestoredCursorPosition()];
    }
}

- (bool)isIgnored:(NSString *)_character
{
    assert(_character.length > 0);
    const auto utf16 = [_character characterAtIndex:0]; // consider uing UTF-32 here ?
    return [m_IgnoreCharacters characterIsMember:utf16];
}

- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView *) [[maybe_unused]] _panel_view
{
    const auto modif = _event.modifierFlags;
    if( !IsQuickSearchModifier(modif, m_Modifier) )
        return view::BiddingPriority::Skip;

    const auto character = _event.charactersIgnoringModifiers;
    if( character.length == 0 )
        return view::BiddingPriority::Skip;

    if( [self isIgnored:character] )
        return view::BiddingPriority::Skip;

    if( IsQuickSearchStringCharacter(character) )
        return view::BiddingPriority::Default;

    bool empty_now =
        m_IsSoftFiltering ? m_Data->SoftFiltering().text.length == 0 : m_Data->HardFiltering().text.text.length == 0;

    if( !empty_now ) {
        if( IsBackspace(character) )
            return view::BiddingPriority::Max;
        if( m_IsSoftFiltering ) {
            if( IsLeft(character) || IsRight(character) || IsUp(character) || IsDown(character) )
                return view::BiddingPriority::Default;
        }
        if( _event.keyCode == 53 ) { // Esc button
            return view::BiddingPriority::Max;
        }
    }

    return view::BiddingPriority::Skip;
}

- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView *) [[maybe_unused]] _panel_view
{
    if( _event.keyCode == 53 ) { // Esc button
        [self setSearchCriteria:nil];
        return;
    }

    if( m_IsSoftFiltering )
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

    const auto is_in_progress = m_SoftFilteringLastAction + g_SoftFilteringTimeout >= nc::base::machtime();
    const auto current = is_in_progress ? m_Data->SoftFiltering().text : static_cast<NSString *>(nil);
    const auto replace = ModifyStringByKeyDownString(current, key);

    if( replace == nil || replace.length == 0 ) {
        [self discardFiltering];
        return;
    }

    [self setSoftFiltering:replace];
}

- (void)setHardFiltering:(NSString *)_text
{
    auto filtering = m_Data->HardFiltering();
    if( filtering.text.text == _text || [filtering.text.text isEqualToString:_text] )
        return;

    filtering.text.text = _text;
    if( filtering.text.text == nil )
        return;

    const auto pers = CursorBackup{[m_Delegate quickSearchNeedsCursorPosition:self], *m_Data};

    filtering.text.type = m_WhereToSearch;
    filtering.text.clear_on_new_listing = true;
    filtering.text.hightlight_results = m_ShowTyping;
    m_Data->SetHardFiltering(filtering);

    [m_Delegate quickSearch:self wantsToSetCursorPosition:pers.RestoredCursorPosition()];

    [m_Delegate quickSearchHasUpdatedData:self];
    [self updateTypingUI];

    // for convinience - if we have ".." and cursor is on it - move it to the first element after
    if( [m_Delegate quickSearchNeedsCursorPosition:self] == 0 && m_Data->SortedDirectoryEntries().size() >= 2 &&
        m_Data->EntryAtRawPosition(m_Data->SortedDirectoryEntries()[0]).IsDotDot() )
        [m_Delegate quickSearch:self wantsToSetCursorPosition:1];
}

- (void)setSoftFiltering:(NSString *)_text
{
    if( !_text )
        return;

    const auto current_time = nc::base::machtime();

    auto filtering = m_Data->SoftFiltering();
    if( m_SoftFilteringLastAction + g_SoftFilteringTimeout < current_time )
        m_SoftFilteringOffset = 0;

    filtering.text = _text;
    filtering.type = m_WhereToSearch;
    filtering.ignore_dot_dot = false;
    filtering.hightlight_results = m_ShowTyping;
    m_Data->SetSoftFiltering(filtering);

    m_SoftFilteringLastAction = current_time;

    const auto filtered_amount = static_cast<int>(m_Data->EntriesBySoftFiltering().size());

    if( filtered_amount != 0 ) {
        if( m_SoftFilteringOffset >= filtered_amount )
            m_SoftFilteringOffset = filtered_amount - 1;
        const auto new_cur_pos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        [m_Delegate quickSearch:self wantsToSetCursorPosition:new_cur_pos];
    }

    if( m_ShowTyping ) {
        [m_Delegate quickSearchHasChangedVolatileData:self];
    }
    [self updateTypingUI];

    [self scheduleSoftFilteringCleanup];
}

- (void)moveToFirstSoftFilteredItem
{
    const auto filtered_amount = static_cast<int>(m_Data->EntriesBySoftFiltering().size());
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = 0;
        const auto new_cur_pos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        [m_Delegate quickSearch:self wantsToSetCursorPosition:new_cur_pos];
        m_SoftFilteringLastAction = nc::base::machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)moveToLastSoftFilteredItem
{
    const auto filtered_amount = static_cast<int>(m_Data->EntriesBySoftFiltering().size());
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = filtered_amount - 1;
        const auto new_cur_pos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        [m_Delegate quickSearch:self wantsToSetCursorPosition:new_cur_pos];
        m_SoftFilteringLastAction = nc::base::machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)moveToPreviousSoftFilteredItem
{
    const auto filtered_amount = static_cast<int>(m_Data->EntriesBySoftFiltering().size());
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = std::max(0, m_SoftFilteringOffset - 1);
        const auto new_cur_pos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        [m_Delegate quickSearch:self wantsToSetCursorPosition:new_cur_pos];
        m_SoftFilteringLastAction = nc::base::machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)moveToNextSoftFilteredItem
{
    const auto filtered_amount = static_cast<int>(m_Data->EntriesBySoftFiltering().size());
    if( filtered_amount != 0 ) {
        m_SoftFilteringOffset = std::min(filtered_amount - 1, m_SoftFilteringOffset + 1);
        const auto new_cur_pos = m_Data->EntriesBySoftFiltering()[m_SoftFilteringOffset];
        [m_Delegate quickSearch:self wantsToSetCursorPosition:new_cur_pos];
        m_SoftFilteringLastAction = nc::base::machtime();
        [self scheduleSoftFilteringCleanup];
    }
}

- (void)scheduleSoftFilteringCleanup
{
    __weak NCPanelQuickSearch *weak_self = self;
    auto clear_filtering = [=] {
        if( NCPanelQuickSearch *const strong_self = weak_self ) {
            if( strong_self->m_SoftFilteringLastAction + g_SoftFilteringTimeout <= nc::base::machtime() )
                [strong_self setSearchCriteria:nil];
        }
    };

    dispatch_to_main_queue_after(g_SoftFilteringTimeout + 1000ns, std::move(clear_filtering));
}

- (void)setPanelHeaderPrompt:(NSString *)_text withMatchesCount:(int)_count
{
    [m_Delegate quickSearch:self wantsToSetSearchPrompt:_text withMatchesCount:_count];
}

- (void)dataUpdated
{
    // TODO: test this in UT
    [self updateTypingUI];
}

- (void)updateTypingUI
{
    if( !m_ShowTyping )
        return;

    if( m_IsSoftFiltering ) {
        const auto filtering = m_Data->SoftFiltering();
        if( filtering.text ) {
            const auto filtered_amount = static_cast<int>(m_Data->EntriesBySoftFiltering().size());
            [self setPanelHeaderPrompt:filtering.text withMatchesCount:filtered_amount];
        }
        else {
            [self setPanelHeaderPrompt:nil withMatchesCount:0];
        }
    }
    else {
        const auto filtering = m_Data->HardFiltering();
        if( filtering.text.text ) {
            int total = static_cast<int>(m_Data->SortedDirectoryEntries().size());
            if( total > 0 && m_Data->Listing().IsDotDot(0) )
                total--;
            [self setPanelHeaderPrompt:filtering.text.text withMatchesCount:total];
        }
        else {
            [self setPanelHeaderPrompt:nil withMatchesCount:0];
        }
    }
}

@end

namespace nc::panel::QuickSearch {

static bool IsQuickSearchModifier(NSUInteger _modif, KeyModif _mode)
{
    // we don't care about CapsLock, Function or NumPad
    _modif &= ~(NSEventModifierFlagCapsLock | NSEventModifierFlagFunction | NSEventModifierFlagNumericPad) &
              (NSEventModifierFlagDeviceIndependentFlagsMask);

    const auto alt = NSEventModifierFlagOption;
    const auto shift = NSEventModifierFlagShift;
    const auto ctrl = NSEventModifierFlagControl;

    switch( _mode ) {
        case KeyModif::WithAlt:
            return _modif == alt || _modif == (alt | shift);
        case KeyModif::WithCtrlAlt:
            return _modif == (alt | ctrl) || _modif == (alt | ctrl | shift);
        case KeyModif::WithShiftAlt:
            return _modif == (alt | shift);
        case KeyModif::WithoutModif:
            return _modif == 0 || _modif == shift;
        default:
            break;
    }
    return false;
}

static bool IsQuickSearchStringCharacter(NSString *_s)
{
    static const auto chars = [] {
        auto set = [NSMutableCharacterSet new];
        [set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [set addCharactersInString:@" "];

        // such character simply can't appear in filename under unix
        [set removeCharactersInString:@"/"];
        return static_cast<NSCharacterSet *>(set);
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
    s = [s substringToIndex:s.length - 1];
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
    if( _k >= 0 && _k <= static_cast<int>(KeyModif::Disabled) )
        return static_cast<KeyModif>(_k);
    return KeyModif::WithAlt;
}

} // namespace nc::panel::QuickSearch
