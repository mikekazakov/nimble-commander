// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewFieldEditor.h"
#include <Operations/FilenameTextControl.h>
#include <Utility/StringExtras.h>
#include <Utility/NSEventModifierFlagsHolder.h>
#include <Panel/Log.h>

using nc::panel::Log;

static NSRange NextFilenameSelectionRange(NSString *_string, NSRange _current_selection);

@implementation NCPanelViewFieldEditor {
    NSTextView *m_TextView;
    NSUndoManager *m_UndoManager;
    VFSListingItem m_OriginalItem;
    bool m_Stashed;
}

@synthesize originalItem = m_OriginalItem;
@synthesize editor = m_TextView;
@synthesize onTextEntered;
@synthesize onEditingFinished;

- (instancetype)initWithItem:(VFSListingItem)_item
{
    self = [super init];
    if( self ) {
        m_Stashed = false;
        m_OriginalItem = _item;
        m_UndoManager = [[NSUndoManager alloc] init];

        [self buildTextView];

        self.borderType = NSNoBorder;
        self.hasVerticalScroller = false;
        self.hasHorizontalScroller = false;
        self.autoresizingMask = NSViewNotSizable;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.horizontalScrollElasticity = NSScrollElasticityNone;
        self.documentView = m_TextView;
    }
    return self;
}

- (void)buildTextView
{
    static const auto ps = []() -> NSParagraphStyle * {
        NSMutableParagraphStyle *const style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByClipping;
        return style;
    }();
    const auto tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    [tv.layoutManager replaceTextStorage:[[NCFilenameTextStorage alloc] init]];
    tv.delegate = self;
    tv.fieldEditor = false;
    tv.allowsUndo = true;
    tv.string = [NSString stringWithUTF8StdString:m_OriginalItem.Filename()];
    tv.selectedRange = NextFilenameSelectionRange(tv.string, tv.selectedRange);
    tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.verticallyResizable = tv.horizontallyResizable = true;
    tv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    tv.richText = false;
    tv.importsGraphics = false;
    tv.allowsImageEditing = false;
    tv.automaticQuoteSubstitutionEnabled = false;
    tv.automaticLinkDetectionEnabled = false;
    tv.continuousSpellCheckingEnabled = false;
    tv.grammarCheckingEnabled = false;
    tv.insertionPointColor = NSColor.textColor;
    tv.backgroundColor = NSColor.textBackgroundColor;
    tv.textColor = NSColor.textColor;
    tv.defaultParagraphStyle = ps;
    tv.textContainer.widthTracksTextView = tv.textContainer.heightTracksTextView = false;
    tv.textContainer.containerSize = CGSizeMake(FLT_MAX, FLT_MAX);
    m_TextView = tv;
}

- (void)markNextFilenamePart
{
    m_TextView.selectedRange = NextFilenameSelectionRange(m_TextView.string, m_TextView.selectedRange);
}

- (BOOL)textShouldEndEditing:(NSText *) [[maybe_unused]] textObject
{
    if( m_Stashed ) {
        Log::Trace("textShouldEndEditing called, stashed, ignoring");
    }
    else {
        Log::Trace("textShouldEndEditing called, accepting");
        [self finishEditing];
    }
    return true;
}

- (void)textDidEndEditing:(NSNotification *) [[maybe_unused]] notification
{
    if( m_Stashed ) {
        Log::Trace("textShouldEndEditing called, stashed, ignoring");
    }
    else {
        Log::Trace("textShouldEndEditing called, accepting");
        [self cancelEditing];
    }
}

- (NSArray *)textView:(NSTextView *) [[maybe_unused]] textView
            completions:(NSArray *) [[maybe_unused]] words
    forPartialWordRange:(NSRange) [[maybe_unused]] charRange
    indexOfSelectedItem:(NSInteger *) [[maybe_unused]] index
{
    return @[];
}

- (BOOL)textView:(NSTextView *) [[maybe_unused]] textView doCommandBySelector:(SEL)commandSelector
{
    static const auto cancel = NSSelectorFromString(@"cancelOperation:");
    static const auto insert_new_line = NSSelectorFromString(@"insertNewline:");
    static const auto insert_tab = NSSelectorFromString(@"insertTab:");
    if( commandSelector == cancel ) {
        [self cancelEditing];
        return true;
    }
    if( commandSelector == insert_new_line || commandSelector == insert_tab ) {
        [self finishEditing];
        return true;
    }
    return false;
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    // manually process Cmd+Backspace that should processed here instead of going into the menu
    // where Move To Trash could pick it.
    using nc::utility::NSEventModifierFlagsHolder;
    const auto keycode = _event.keyCode;
    const auto flags = NSEventModifierFlagsHolder(_event.modifierFlags);
    if( keycode == 51 && flags == NSEventModifierFlagsHolder(NSEventModifierFlagCommand) ) {
        [m_TextView doCommandBySelector:@selector(deleteToBeginningOfLine:)];
        return true;
    }
    return [super performKeyEquivalent:_event];
}

- (void)finishEditing
{
    if( m_TextView.string && m_TextView.string.length > 0 )
        if( const auto utf8 = m_TextView.string.fileSystemRepresentation ) {
            auto enter_handler = self.onTextEntered;
            self.onTextEntered = nil;
            if( enter_handler ) {
                enter_handler(utf8);
            }
        }

    auto finish_handler = self.onEditingFinished;
    self.onEditingFinished = nil;
    if( finish_handler ) {
        finish_handler();
    }
}

- (void)cancelEditing
{
    Log::Trace("cancelEditing called");
    self.onTextEntered = nil;
    auto finish_handler = self.onEditingFinished;
    self.onEditingFinished = nil;
    if( finish_handler ) {
        finish_handler();
    }
}

- (nullable NSUndoManager *)undoManagerForTextView:(NSTextView *) [[maybe_unused]] view
{
    return m_UndoManager;
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    Log::Trace("viewWillMoveToWindow: {}", (__bridge void *)_wnd);
    const auto notify_center = NSNotificationCenter.defaultCenter;
    if( self.window ) {
        [notify_center removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
        [notify_center removeObserver:self name:NSWindowDidResignMainNotification object:nil];
    }
    if( _wnd ) {
        [notify_center addObserver:self
                          selector:@selector(windowStatusDidChange)
                              name:NSWindowDidResignKeyNotification
                            object:_wnd];
        [notify_center addObserver:self
                          selector:@selector(windowStatusDidChange)
                              name:NSWindowDidResignMainNotification
                            object:_wnd];
    }
}

- (void)windowStatusDidChange
{
    Log::Trace("windowStatusDidChange called");
    [self finishEditing];
}

static NSRange NextFilenameSelectionRange(NSString *_string, NSRange _current_selection)
{
    static auto dot = [NSCharacterSet characterSetWithCharactersInString:@"."];

    // disassemble filename into parts
    const auto length = _string.length;
    const NSRange whole = NSMakeRange(0, length);
    NSRange name;
    std::optional<NSRange> extension;

    const NSRange r = [_string rangeOfCharacterFromSet:dot options:NSBackwardsSearch];
    if( r.location > 0 && r.location < length - 1 ) { // has extension
        name = NSMakeRange(0, r.location);
        extension = NSMakeRange(r.location + 1, length - r.location - 1);
    }
    else { // no extension
        name = whole;
    }

    if( _current_selection.length == 0 ) // no selection currently - return name
        return name;
    else {
        if( NSEqualRanges(_current_selection, name) ) // current selection is name only
            return extension ? *extension : whole;
        else if( NSEqualRanges(_current_selection, whole) ) // current selection is all filename
            return name;
        else
            return whole;
    }
}

- (void)stash
{
    Log::Trace("stash called");
    m_Stashed = true;
}

- (void)unstash
{
    Log::Trace("unstash called");
    m_Stashed = false;
}

@end
