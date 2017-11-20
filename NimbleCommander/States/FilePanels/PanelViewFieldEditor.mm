// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewFieldEditor.h"
#include <Utility/FilenameTextControl.h>

static NSRange NextFilenameSelectionRange( NSString *_string, NSRange _current_selection );

@implementation NCPanelViewFieldEditor
{
    NSTextView      *m_TextView;
    NSUndoManager   *m_UndoManager;
    VFSListingItem   m_OriginalItem;
}

@synthesize textView = m_TextView;
@synthesize originalItem = m_OriginalItem;

- (instancetype)initWithItem:(VFSListingItem)_item
{
    self = [super init];
    if( self ) {
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

- (void) buildTextView
{
   static const auto ps = []()-> NSParagraphStyle* {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByClipping;
        return style;
    }();
    const auto tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    [tv.layoutManager replaceTextStorage:[[NCFilenameTextStorage alloc] init]];
    tv.delegate = self;
    tv.fieldEditor = true;
    tv.allowsUndo = true;
    tv.string = [NSString stringWithUTF8StdString:m_OriginalItem.Filename()];
    tv.selectedRange = NextFilenameSelectionRange( tv.string, tv.selectedRange );
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
    tv.insertionPointColor = NSColor.blackColor;
    tv.backgroundColor = NSColor.whiteColor;
    tv.textColor = NSColor.blackColor;
    tv.defaultParagraphStyle = ps;
    tv.textContainer.widthTracksTextView = tv.textContainer.heightTracksTextView = false;
    tv.textContainer.containerSize = CGSizeMake(FLT_MAX, FLT_MAX);
    m_TextView = tv;
}

- (void)markNextFilenamePart
{
    m_TextView.selectedRange = NextFilenameSelectionRange(m_TextView.string,
                                                          m_TextView.selectedRange );
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{
    if( m_TextView.string && m_TextView.string.length > 0)
        if( const auto utf8 = m_TextView.string.fileSystemRepresentation )
            if( self.onTextEntered )
                self.onTextEntered(utf8);
    return true;
}

- (void)textDidEndEditing:(NSNotification *)notification
{
    if( self.onEditingFinished )
        self.onEditingFinished();
}

- (NSArray *)textView:(NSTextView *)textView
          completions:(NSArray *)words
  forPartialWordRange:(NSRange)charRange
  indexOfSelectedItem:(NSInteger *)index
{
    return @[];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    static const auto cancel = NSSelectorFromString(@"cancelOperation:");
    if( commandSelector == cancel ) {
        self.onTextEntered = nil;
        if( self.onEditingFinished )
            self.onEditingFinished();
        return true;
    }
    return false;
}

- (nullable NSUndoManager *)undoManagerForTextView:(NSTextView *)view
{
    return m_UndoManager;
}

static NSRange NextFilenameSelectionRange( NSString *_string, NSRange _current_selection )
{
    static auto dot = [NSCharacterSet characterSetWithCharactersInString:@"."];

    // disassemble filename into parts
    const auto length = _string.length;
    const NSRange whole = NSMakeRange(0, length);
    NSRange name;
    optional<NSRange> extension;
    
    const NSRange r = [_string rangeOfCharacterFromSet:dot options:NSBackwardsSearch];
    if( r.location > 0 && r.location < length - 1) { // has extension
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

@end
