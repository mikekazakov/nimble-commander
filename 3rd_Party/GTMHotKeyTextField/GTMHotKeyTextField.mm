//  GTMHotKeyTextField.m
//
//  Copyright 2006-2010 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import "GTMHotKeyTextField.h"
#import <Carbon/Carbon.h>
#include <vector>

struct KeycodesHardcode
{
    uint32_t keycode;
    uint16_t unicode;
    NSString *vis;
};

static const std::vector<KeycodesHardcode> g_KeycodesHardcoded = {
    {123,   NSLeftArrowFunctionKey,     @"←"},
    {124,   NSRightArrowFunctionKey,    @"→"},
    {125,   NSDownArrowFunctionKey,     @"↓"},
    {126,   NSUpArrowFunctionKey,       @"↑"},
    {122,   NSF1FunctionKey,            @"F1"},
    {120,   NSF2FunctionKey,            @"F2"},
    {99,    NSF3FunctionKey,            @"F3"},
    {118,   NSF4FunctionKey,            @"F4"},
    {96,    NSF5FunctionKey,            @"F5"},
    {97,    NSF6FunctionKey,            @"F6"},
    {98,    NSF7FunctionKey,            @"F7"},
    {100,   NSF8FunctionKey,            @"F8"},
    {101,   NSF9FunctionKey,            @"F9"},
    {109,   NSF10FunctionKey,           @"F10"},
    {103,   NSF11FunctionKey,           @"F11"},
    {111,   NSF12FunctionKey,           @"F12"},
    {105,   NSF13FunctionKey,           @"F13"},
    {107,   NSF14FunctionKey,           @"F14"},
    {113,   NSF15FunctionKey,           @"F15"},
    {106,   NSF16FunctionKey,           @"F16"},
    {64,    NSF17FunctionKey,           @"F17"},
    {79,    NSF18FunctionKey,           @"F18"},
    {80,    NSF19FunctionKey,           @"F19"},
    {117,   0x2326,                     @"⌦"},
    {36,    '\r',                       @"↩"},
    {76,    0x3,                        @"⌅"},
    {48,    0x9,                        @"⇥"},
    {49,    0x0020,                     @"Space"},
    {49,    0x2423,                     @"Space"},
    {51,    0x8,                        @"⌫"},
    {71,    NSClearDisplayFunctionKey,  @"Clear"},
    {53,    0x1B,                       @"⎋"},
    {115,   NSHomeFunctionKey,          @"↖"},
    {116,   NSPageUpFunctionKey,        @"⇞"},
    {119,   NSEndFunctionKey,           @"↘"},
    {121,   NSPageDownFunctionKey,      @"⇟"},
    {114,   NSHelpFunctionKey,          @"Help"},
    {65,    '.',                        @"."},
    {67,    '*',                        @"*"},
    {69,    '+',                        @"+"},
    {75,    '/',                        @"/"},
    {78,    '-',                        @"-"},
    {81,    '=',                        @"="},
    {82,    '0',                        @"0"},
    {83,    '1',                        @"1"},
    {84,    '2',                        @"2"},
    {85,    '3',                        @"3"},
    {86,    '4',                        @"4"},
    {87,    '5',                        @"5"},
    {88,    '6',                        @"6"},
    {89,    '7',                        @"7"},
    {91,    '8',                        @"8"},
    {92,    '9',                        @"9"}
};

@implementation GTMHotKey {
    NSUInteger m_Modif;
    NSString  *m_Key;
    NSString  *m_VisKey;
}

+ (id)hotKeyWithKey:(NSString *)str
          modifiers:(NSUInteger)modifiers {
    return [[self alloc] initWithKey:str modifiers:modifiers];
}

+ (GTMHotKey*)emptyHotKey
{
    static GTMHotKey* eh = nil;
    if(!eh) {
        eh = [GTMHotKey new];
        eh->m_Key = @"";
        eh->m_Modif = 0;
        eh->m_VisKey = @"";
    }
    return eh;
}

- (id)initWithKey:(NSString *)str
        modifiers:(NSUInteger)modifiers {
    if ((self = [super init])) {
        m_Modif = modifiers;
        m_Key = str;
        m_VisKey = [str uppercaseString];
        
        if(str.length > 0) {
            uint16_t c = [str characterAtIndex:0];
            for(auto &i: g_KeycodesHardcoded)
                if(i.unicode == c) {
                    m_VisKey = i.vis;
                    break;
                }
        }
    }
    return self;
}

- (NSUInteger)modifiers {
  return m_Modif;
}

- (NSString *)key {
    return m_Key;
}

- (NSString *)visualKey {
    return m_VisKey;
}

- (bool)isEmpty {
    return m_Key == nil || [m_Key isEqualToString:@""];
}

- (BOOL)isEqual:(id)object {
  return [object isKindOfClass:GTMHotKey.class]
    && [object modifiers] == [self modifiers]
    && [[object key] isEqualToString:m_Key];
}

- (NSUInteger)hash {
  return m_Modif + [m_Key characterAtIndex:0];
}

- (id)copyWithZone:(NSZone *)zone
{
    GTMHotKey *hk = [[GTMHotKey allocWithZone:zone] init];
    hk->m_Modif     = m_Modif;
    hk->m_Key       = m_Key;
    hk->m_VisKey    = m_VisKey;
    return hk;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p> - %@",
          [self class], self,
          m_VisKey];
}

@end

@implementation GTMHotKeyTextField

+ (Class)cellClass {
  return GTMHotKeyTextFieldCell.class;
}

@end

@implementation GTMHotKeyTextFieldCell
{
    GTMHotKey *hotKey_;
    GTMHotKeyFieldEditor *m_FieldEditor;
    bool m_StrictModifierRequirement;
}

@synthesize strictModifierRequirement = m_StrictModifierRequirement;

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if( self = [super initWithCoder:aDecoder] ) {
        m_StrictModifierRequirement = true;
        
        
    }
    return self;
    
}

- (id)copyWithZone:(NSZone *)zone {
  GTMHotKeyTextFieldCell *copy = [super copyWithZone:zone];
  copy->hotKey_ = nil;
  [copy setObjectValue:[self objectValue]];
  return copy;
}

- (void)logBadValueAccess {
  NSLog(@"Hot key fields want hot key dictionaries as object values.");
}

- (id)objectValue {
  return hotKey_;
}

- (NSTextView *)fieldEditorForView:(NSView *)aControlView
{
    if(m_FieldEditor == nil)
        m_FieldEditor = [GTMHotKeyFieldEditor new];
    [m_FieldEditor setCell:self];
    return m_FieldEditor;
}

- (void)setObjectValue:(id)object {
    // Sanity only if set, nil is OK
    if (object && ![object isKindOfClass:GTMHotKey.class]) {
        [self logBadValueAccess];
        return;
    }
    if (![hotKey_ isEqual:object]) {
        // Otherwise we directly update ourself
        hotKey_ = [object copy];
        [self updateDisplayedPrettyString];
    }
}

- (NSString *)stringValue {
    NSString *value = [GTMHotKeyTextFieldCell displayStringForHotKey:hotKey_];
    return value ? value : @"";
}

- (void)setStringValue:(NSString *)string {
    // Since we are a text cell, lots of AppKit objects will attempt to
    // set out string value. Our Field editor should already have done
    // that for us, so check to make sure what AppKit is setting us to is
    // what we expect.
    if (![string isEqual:self.stringValue])
        [self logBadValueAccess];
}

- (NSAttributedString *)attributedStringValue {
    if (NSString *prettyString = self.stringValue)
        return [[NSAttributedString alloc] initWithString:prettyString];
    return nil;
}

- (void)setAttributedStringValue:(NSAttributedString *)string {
  [self logBadValueAccess];
}

- (id)formatter {
    return nil;
}

- (void)setFormatter:(NSFormatter *)newFormatter {
}

// Private method to update the displayed text of the field with the
// user-readable representation.
- (void)updateDisplayedPrettyString {
    // Pretty string
    NSString *prettyString = [GTMHotKeyTextFieldCell displayStringForHotKey:hotKey_];
    [super setObjectValue:prettyString ? prettyString : @"'"];
}

+ (NSString *)displayStringForHotKey:(GTMHotKey *)hotKey {
    if (!hotKey)
        return nil;

    // Modifiers
    NSUInteger modifiers = hotKey.modifiers;
    NSString *mods = [GTMHotKeyTextFieldCell stringForModifierFlags:modifiers];
    if (modifiers && !mods.length)
        return nil;
    
    NSString *keystroke = hotKey.visualKey;
    
    return [NSString stringWithFormat:@"%@%@", mods, keystroke];
}

#pragma mark Useful String Class Methods

- (BOOL)doesKeyCodeRequireModifier:(UInt16)keycode {
    if( !m_StrictModifierRequirement )
        return false;
    
    BOOL doesRequire = YES;
    switch(keycode) {
        // These are the keycodes that map to the
        //unichars in the associated comment.
        case 122:  //  NSF1FunctionKey
        case 120:  //  NSF2FunctionKey
        case 99:   //  NSF3FunctionKey
        case 118:  //  NSF4FunctionKey
        case 96:   //  NSF5FunctionKey
        case 97:   //  NSF6FunctionKey
        case 98:   //  NSF7FunctionKey
        case 100:  //  NSF8FunctionKey
        case 101:  //  NSF9FunctionKey
        case 109:  //  NSF10FunctionKey
        case 103:  //  NSF11FunctionKey
        case 111:  //  NSF12FunctionKey
        case 105:  //  NSF13FunctionKey
        case 107:  //  NSF14FunctionKey
        case 113:  //  NSF15FunctionKey
        case 106:  //  NSF16FunctionKey
        case 64:   //  NSF17FunctionKey
        case 79:   //  NSF18FunctionKey
        case 80:   //  NSF19FunctionKey
        case 115:  //  NSHomeFunctionKey
        case 119:  //  NSEndFunctionKey
        case 116:  //  NSPageUpFunctionKey
        case 121:  //  NSPageDownFunctionKey
        case 76:   //  NSInsertFunctionKey
        case 36:   //  enter key
            doesRequire = NO;
            break;
        default:
            doesRequire = YES;
            break;
    }
    return doesRequire;
}

// These are not in a category on NSString because this class could be used
// within multiple preference panes at the same time. If we put it in a category
// it would require setting up some magic so that the categories didn't conflict
// between the multiple pref panes. By putting it in the class, you can just
// #define the class name to something else, and then you won't have any
// conflicts.

+ (NSString *)stringForModifierFlags:(NSUInteger)flags {
    UniChar modChars[4];  // We only look for 4 flags
    unsigned int charCount = 0;
    // These are in the same order as the menu manager shows them
    if (flags & NSControlKeyMask)   modChars[charCount++] = kControlUnicode;
    if (flags & NSAlternateKeyMask) modChars[charCount++] = kOptionUnicode;
    if (flags & NSShiftKeyMask)     modChars[charCount++] = kShiftUnicode;
    if (flags & NSCommandKeyMask)   modChars[charCount++] = kCommandUnicode;
    if (charCount == 0) return @"";
    return [NSString stringWithCharacters:modChars length:charCount];
}

// Convert a keycode into a string that would result from typing the keycode in
// the current keyboard layout. This may be one or more characters.
//
// Args:
//   keycode: Virtual keycode such as one obtained from NSEvent
//   useGlyph: In many cases the glyphs are confusing, and a string is clearer.
//             However, if you want to display in a menu item, use must
//             have a glyph. Set useGlyph to FALSE to get localized strings
//             which are better for UI display in places other than menus.
//     bundle: Localization bundle to use for localizable key names
//
// Returns:
//   Autoreleased NSString
//
+ (NSString *)stringForKeycode:(UInt16)keycode
                      useGlyph:(BOOL)useGlyph {
  // Some keys never move in any layout (to the best of our knowledge at least)
  // so we can hard map them.
  UniChar key = 0;
  NSString *vis_key = nil;
    
    for(auto &kc: g_KeycodesHardcoded)
        if(kc.keycode == keycode) {
            key = kc.unicode;
            vis_key = kc.vis;
            break;
        }
    
  // If they asked for strings, and we have one return it.  Otherwise, return
  // any key we've picked.
  if (!useGlyph && vis_key)
      return vis_key;
  else if (key != 0)
    return [NSString stringWithFormat:@"%C", key];

  // Everything else should be printable so look it up in the current keyboard
  UCKeyboardLayout *uchrData = NULL;

  OSStatus err = noErr;
  TISInputSourceRef inputSource = TISCopyCurrentKeyboardLayoutInputSource();
  if (inputSource) {
    CFDataRef uchrDataRef
      = (CFDataRef) TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData);
    if(uchrDataRef) {
      uchrData = (UCKeyboardLayout*)CFDataGetBytePtr(uchrDataRef);
    }
    CFRelease(inputSource);
  }

  NSString *keystrokeString = nil;
  if (uchrData) {
    // uchr layout data is available, this is our preference
    UniCharCount uchrCharLength = 0;
    UniChar  uchrChars[256] = { 0 };
    UInt32 uchrDeadKeyState = 0;
    err = UCKeyTranslate(uchrData,
                         keycode,
                         kUCKeyActionDisplay,
                         0,  // No modifiers
                         LMGetKbdType(),
                         kUCKeyTranslateNoDeadKeysMask,
                         &uchrDeadKeyState,
                         sizeof(uchrChars) / sizeof(UniChar),
                         &uchrCharLength,
                         uchrChars);
    if (err != noErr)
      return nil;
    if (uchrCharLength < 1)
        return nil;
    keystrokeString = [NSString stringWithCharacters:uchrChars length:uchrCharLength];
  }

    // Sanity we got a stroke
  if (!keystrokeString || !keystrokeString.length) return nil;

  // Sanity check the keystroke string for unprintable characters
  NSMutableCharacterSet *validChars = [NSMutableCharacterSet new];

  [validChars formUnionWithCharacterSet:NSCharacterSet.alphanumericCharacterSet];
  [validChars formUnionWithCharacterSet:NSCharacterSet.punctuationCharacterSet];
  [validChars formUnionWithCharacterSet:NSCharacterSet.symbolCharacterSet];
  for (unsigned int i = 0; i < keystrokeString.length; i++)
    if (![validChars characterIsMember:[keystrokeString characterAtIndex:i]])
      return nil;

  if (!useGlyph) {
    // menus want glyphs in the original lowercase forms, so we only upper this
    // if we aren't using it as a glyph.
    keystrokeString = [keystrokeString uppercaseString];
  }

  return keystrokeString;
}

@end

@implementation GTMHotKeyFieldEditor
{
    NSButton *m_ClearButton;
    NSButton *m_RevertButton;
}

+ (GTMHotKeyFieldEditor *)sharedHotKeyFieldEditor {
    static GTMHotKeyFieldEditor *obj = [self new];
    return obj;
}

- (id)init {
  if (self = [super init])
    self.fieldEditor = YES;  // We are a field editor
  return self;
}

- (NSArray *)acceptableDragTypes { return @[]; /* Don't take drags */ }
- (NSArray *)readablePasteboardTypes { return @[]; /* No pasting */ }
- (NSArray *)writablePasteboardTypes { return @[]; /* No copying */ }

- (BOOL)becomeFirstResponder {
  // We need to lose focus any time the window is not key
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(windowResigned:)
                                               name:NSWindowDidResignKeyNotification
                                             object:self.window];
    if( !m_ClearButton ) {
        m_ClearButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 20, (self.bounds.size.height - 22)/2, 22, 22)];
        m_ClearButton.title = @"−";
        m_ClearButton.font = [NSFont labelFontOfSize:9];
        m_ClearButton.refusesFirstResponder = true;
        m_ClearButton.bezelStyle = NSCircularBezelStyle;
        m_ClearButton.target = self;
        m_ClearButton.action = @selector(OnClearButton:);
        ((NSButtonCell*)m_ClearButton.cell).controlSize = NSMiniControlSize;
        [self addSubview:m_ClearButton];
    }
    
    if( !m_RevertButton ) {
        m_RevertButton = [[NSButton alloc] initWithFrame:NSMakeRect(self.bounds.size.width - 36, (self.bounds.size.height - 22)/2, 22, 22)];
        m_RevertButton.title = @"↺";
        m_RevertButton.font = [NSFont labelFontOfSize:9];
        m_RevertButton.refusesFirstResponder = true;
        m_RevertButton.bezelStyle = NSCircularBezelStyle;
        m_RevertButton.target = self;
        m_RevertButton.action = @selector(OnRevertButton:);
        ((NSButtonCell*)m_RevertButton.cell).controlSize = NSMiniControlSize;
        [self addSubview:m_RevertButton];
    }
    
    return [super becomeFirstResponder];
}

- (void)OnClearButton:(id)sender
{
    [self.cell setObjectValue:GTMHotKey.emptyHotKey];
    [self didChangeText];
    [self.window makeFirstResponder:nil];
}

- (void)OnRevertButton:(id)sender
{
    if( self.cell.defaultHotKey ) {
        [self.cell setObjectValue:self.cell.defaultHotKey];
        [self didChangeText];
        [self.window makeFirstResponder:nil];
    }
}

- (BOOL)resignFirstResponder {
  // No longer interested in window resign
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if(m_ClearButton) {
        [m_ClearButton removeFromSuperview];
        m_ClearButton = nil;
    }

    return [super resignFirstResponder];
}

// Private method we use to get out of global hotkey capture when the window
// is no longer front
- (void)windowResigned:(NSNotification *)notification {
  // Lose our focus
  [self.window makeFirstResponder:self.window];
}

- (BOOL)shouldDrawInsertionPoint {
  // Show an insertion point, because we'll kill our own focus after
  // each entry
  return YES;
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange
                              granularity:(NSSelectionGranularity)granularity {
  // Always select everything
  return NSMakeRange(0, self.textStorage.length);
}

- (void)keyDown:(NSEvent *)theEvent {
    if ([self shouldBypassEvent:theEvent])
        [super keyDown:theEvent];
    else
        [self processEventToHotKeyAndString:theEvent]; // Try to eat the event
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
    if ([self shouldBypassEvent:theEvent])
        return [super performKeyEquivalent:theEvent];

    // We always eat these key strokes while we have focus
    [self processEventToHotKeyAndString:theEvent];
    return YES;
}

// Private do method that tell us to ignore certain events
- (BOOL)shouldBypassEvent:(NSEvent *)theEvent {
  BOOL bypass = NO;
  UInt16 keyCode = theEvent.keyCode;
  NSUInteger modifierFlags = theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask;

  if (keyCode == 48) {  // Tab
    // Ignore all events that the dock cares about
    // Just to be extra clear if the user is trying to use Dock hotkeys beep
    // at them
    if ((modifierFlags == NSCommandKeyMask) ||
        (modifierFlags == (NSCommandKeyMask | NSShiftKeyMask))) {
      NSBeep();
      bypass = YES;
    } else if (modifierFlags == 0 || modifierFlags == NSShiftKeyMask) {
      // Probably attempting to tab around the dialog.
      bypass = YES;
    }

  } else if ((keyCode == 12) && (modifierFlags == NSCommandKeyMask)) {
    // Don't eat Cmd-Q. Users could have it as a hotkey, but its more likely
    // they're trying to quit
    bypass = YES;
  } else if ((keyCode == 13) && (modifierFlags == NSCommandKeyMask)) {
    // Same for Cmd-W, user is probably trying to close the window
    bypass = YES;
  }
  return bypass;
}

// Private method that turns events into strings and dictionaries for our
// hotkey plumbing.
- (void)processEventToHotKeyAndString:(NSEvent *)theEvent {
    // Construct a dictionary of the event as a hotkey pref
    GTMHotKey *newHotKey = GTMHotKey.emptyHotKey;
    NSString *prettyString = @"";
    // 51 is "the delete key"
    static const NSUInteger allModifiers = (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask);
    if (!((theEvent.keyCode == 51 ) && ((theEvent.modifierFlags & allModifiers)== 0))) {
        newHotKey = [self hotKeyForEvent:theEvent];
        if (!newHotKey) {
            NSBeep();
            return;  // No action, but don't give up focus
        }
        prettyString = [GTMHotKeyTextFieldCell displayStringForHotKey:newHotKey];
        if (!prettyString) {
            NSBeep();
            return;
        }
    }

    // Replacement range
    NSRange replaceRange = NSMakeRange(0, self.textStorage.length);

    // Ask for permission to replace
    if (![self shouldChangeTextInRange:replaceRange replacementString:prettyString]) {
        // If replacement was disallowed, change nothing, including hotKeyDict_
        NSBeep();
        return;
    }

    [self.cell setObjectValue:newHotKey];

    // Finish the change
    [self didChangeText];

    // Force editing to end. This sends focus off into space slightly, but
    // its better than constantly capturing user events. This is exactly
    // like the Apple editor in their Keyboard pref pane.
    [self.window makeFirstResponder:nil];
}

- (GTMHotKey *)hotKeyForEvent:(NSEvent *)event {
  if (!event) return nil;

  // Check event
  NSUInteger flags = event.modifierFlags;
  UInt16 keycode = event.keyCode;
  // If the event has no modifiers do nothing
  const NSUInteger allModifiers = (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask);

  if ([self.cell doesKeyCodeRequireModifier:keycode]) {
    // If we aren't a function key, and have no modifiers do nothing.
    if (!(flags & allModifiers)) return nil;
    // If the event has high bits in keycode do nothing
    if (keycode & 0xFF00) return nil;
  }
    
    NSString *stroke = [GTMHotKeyTextFieldCell stringForKeycode:keycode useGlyph:true];
    if(stroke == nil)
        return nil;
    
//    + (NSString *)stringForKeycode:(UInt16)keycode
//useGlyph:(BOOL)useGlyph {


  // Clean the flags to only contain things we care about
  UInt32 cleanFlags = 0;
  if (flags & NSCommandKeyMask)     cleanFlags |= NSCommandKeyMask;
  if (flags & NSAlternateKeyMask)   cleanFlags |= NSAlternateKeyMask;
  if (flags & NSControlKeyMask)     cleanFlags |= NSControlKeyMask;
  if (flags & NSShiftKeyMask)       cleanFlags |= NSShiftKeyMask;
//  return [GTMHotKey hotKeyWithKeyCode:keycode modifiers:cleanFlags];
    return [GTMHotKey hotKeyWithKey:stroke modifiers:cleanFlags];
    
    
    
}

@end
