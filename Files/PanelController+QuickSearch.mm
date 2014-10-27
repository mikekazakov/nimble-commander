//
//  PanelController+QuickSearch.m
//  Files
//
//  Created by Michael G. Kazakov on 25.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+QuickSearch.h"
#import "Common.h"

static const nanoseconds g_FastSeachDelayTresh = 4s;

static bool IsQuickSearchModifier(NSUInteger _modif, PanelQuickSearchMode::KeyModif _mode)
{
    // exclude CapsLock from our decision process
    _modif &= ~NSAlphaShiftKeyMask;
    
    switch (_mode) {
        case PanelQuickSearchMode::WithAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithCtrlAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask) ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithShiftAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithoutModif:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == 0 ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == NSShiftKeyMask ;
        default:
            break;
    }
    return false;
}

static bool IsQuickSearchModifierForArrows(NSUInteger _modif, PanelQuickSearchMode::KeyModif _mode)
{
    // exclude CapsLock from our decision process
    _modif &= ~NSAlphaShiftKeyMask;
    
    // arrow keydowns have NSNumericPadKeyMask and NSFunctionKeyMask flag raised
    if((_modif & NSNumericPadKeyMask) == 0) return false;
    if((_modif & NSFunctionKeyMask) == 0) return false;
    _modif &= ~NSNumericPadKeyMask;
    _modif &= ~NSFunctionKeyMask;
    
    switch (_mode) {
        case PanelQuickSearchMode::WithAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithCtrlAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask) ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithShiftAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        default:
            break;
    }
    return false;
}

static bool IsQuickSearchStringCharacter(NSString *_s)
{
    static NSCharacterSet *chars;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *un = [NSMutableCharacterSet new];
        [un formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [un removeCharactersInString:@"/"]; // such character simply can't appear in filename under unix
        chars = un;
    });
    
    if(_s.length == 0)
        return false;
    
    unichar u = [_s characterAtIndex:0]; // consider uing UTF-32 here
    return [chars characterIsMember:u];
}

static inline bool IsBackspace(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0x7F;
}

static inline bool IsSpace(NSString *_s)
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

@implementation PanelController (QuickSearch)


- (void) QuickSearchClearFiltering
{
    if(m_View == nil)
        return;
    
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    if(m_Data.ClearTextFiltering()) {
        pers.Restore();
        [m_View setNeedsDisplay:true];
    }
    
    m_View.quickSearchPrompt = nil;
}

- (bool)HandleQuickSearchSoft: (NSString*) _key
{
    nanoseconds currenttime = machtime();
    if(_key != nil)
    {
        // update soft filtering
        PanelDataTextFiltering filtering = m_Data.SoftFiltering();

        if(!IsBackspace(_key))
        {
            if(m_QuickSearchLastType + g_FastSeachDelayTresh < currenttime ||
               filtering.text == nil)
            {
                filtering.text = _key; // flush
                m_QuickSearchOffset = 0;
            }
            else
                filtering.text = [filtering.text stringByAppendingString:_key]; // append
        }
        else
        {
            if(filtering.text != nil && filtering.text.length > 0 )
                filtering.text = RemoveLastCharacterWithNormalization(filtering.text);
            else
                return false;
        }
        
        filtering.type = m_QuickSearchWhere;
        filtering.ignoredotdot = false;
        m_Data.SetSoftFiltering(filtering);
    }
    m_QuickSearchLastType = currenttime;
    
    if(m_Data.SoftFiltering().text == nil)
        return false;
    
    if(!m_Data.EntriesBySoftFiltering().empty())
    {
        if(m_QuickSearchOffset >= m_Data.EntriesBySoftFiltering().size())
            m_QuickSearchOffset = (unsigned)m_Data.EntriesBySoftFiltering().size() - 1;
        m_View.curpos = m_Data.EntriesBySoftFiltering()[m_QuickSearchOffset];
    }
    
    if(m_QuickSearchTypingView)
    {
        int total = (int)m_Data.EntriesBySoftFiltering().size();
        NSString *prompt = nil;
        if(total == 0)
            prompt = [NSString stringWithFormat:@"Not found | %@", m_Data.SoftFiltering().text];
        else if(total == 1)
            prompt = [NSString stringWithFormat:@"1 match | %@", m_Data.SoftFiltering().text];
        else
            prompt = [NSString stringWithFormat:@"%i matches | %@", total, m_Data.SoftFiltering().text];
        m_View.quickSearchPrompt = prompt;
        m_View.needsDisplay = true;
        
        // automatically remove prompt after g_FastSeachDelayTresh
        __weak PanelController *wself = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration_cast<nanoseconds>(g_FastSeachDelayTresh).count() + 1000), dispatch_get_main_queue(), ^{
            if(PanelController *sself = wself)
                if(sself->m_QuickSearchLastType + g_FastSeachDelayTresh <= machtime()) {
                    sself->m_View.quickSearchPrompt = nil;
                    sself->m_View.needsDisplay = true;
                }
        });
    }
    return true;
}

- (bool)HandleQuickSearchHard: (NSString*) _key
{
    PanelDataHardFiltering filtering = m_Data.HardFiltering();
    
    if(_key != nil)
    {
        // update hard filtering
        if(!IsBackspace(_key))
        {
            if(filtering.text.text == nil)
                filtering.text.text = _key;
            else
                filtering.text.text = [filtering.text.text stringByAppendingString:_key];
        }
        else
        {
            if(filtering.text.text != nil && filtering.text.text.length > 0 )
                filtering.text.text = RemoveLastCharacterWithNormalization(filtering.text.text);
            else
                return false;
        }
    }
    
    if(filtering.text.text == nil)
        return false;
    
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    filtering.text.type = m_QuickSearchWhere;
    filtering.text.clearonnewlisting = true;
    m_Data.SetHardFiltering(filtering);
    
    pers.Restore();
    
    // for convinience - if we have ".." and cursor is on it - move it to first element (if any)
    if((m_VFSFetchingFlags & VFSHost::F_NoDotDot) == 0 &&
       m_View.curpos == 0 &&
       m_Data.SortedDirectoryEntries().size() >= 2 &&
       m_Data.EntryAtRawPosition(m_Data.SortedDirectoryEntries()[0])->IsDotDot() )
        m_View.curpos = 1;
    
    [m_View setNeedsDisplay:true];
    
    if(m_QuickSearchTypingView) { // update typing UI
        int total = (int)m_Data.SortedDirectoryEntries().size();
        if(total > 0 &&
           m_Data.Listing()->At(0).IsDotDot())
            total--;

        NSString *prompt = nil;
        if(total == 0)
            prompt = [NSString stringWithFormat:@"Not found | %@", filtering.text.text];
        else if(total == 1)
            prompt = [NSString stringWithFormat:@"1 match | %@", filtering.text.text];
        else
            prompt = [NSString stringWithFormat:@"%i matches | %@", total, filtering.text.text];
        m_View.quickSearchPrompt = prompt;
        m_View.needsDisplay = true;        
    }
    return true;
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
       )
    {
        [m_View disableCurrentMomentumScroll];
        if(m_QuickSearchIsSoftFiltering)
            return [self HandleQuickSearchSoft:character.decomposedStringWithCanonicalMapping];
        else
            return [self HandleQuickSearchHard:character.decomposedStringWithCanonicalMapping];
    }
    else if([character length] == 1)
        switch([character characterAtIndex:0])
        {
            case NSUpArrowFunctionKey:
                if(IsQuickSearchModifierForArrows(modif, m_QuickSearchMode))
                {
                    [m_View disableCurrentMomentumScroll];
                    [self QuickSearchPrevious];
                    return true;
                }
            case NSDownArrowFunctionKey:
                if(IsQuickSearchModifierForArrows(modif, m_QuickSearchMode))
                {
                    [m_View disableCurrentMomentumScroll];
                    [self QuickSearchNext];
                    return true;
                }
        }
    
    return false;
}

@end
