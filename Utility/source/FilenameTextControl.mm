// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FilenameTextControl.h"
#include <AppKit/AppKit.h>
#include "ObjCpp.h"
#include "FilenameTextNavigation.h"

@interface NCFilenameTextStorage ()
@property (nonatomic, strong) NSMutableAttributedString *backingStore;
@property (nonatomic, strong) NSMutableDictionary *attributes;
@end

@implementation NCFilenameTextStorage

- (instancetype) init
{
    if( self = [super init] ) {
        self.backingStore = [NSMutableAttributedString new];
        self.attributes = [@{} mutableCopy];
    }
    return self;
}

- (NSString *)string
{
    return self.backingStore.string;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location
                     effectiveRange:(NSRangePointer)range
{
    return [self.backingStore attributesAtIndex:location
                                 effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    [self beginEditing];
    [self.backingStore replaceCharactersInRange:range withString:str];
    [self edited:NSTextStorageEditedCharacters
           range:range
  changeInLength:(NSInteger)str.length - (NSInteger)range.length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    [self beginEditing];
    [self.backingStore setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
    [self endEditing];
}

- (NSUInteger)nextWordFromIndex:(NSUInteger)location
                        forward:(BOOL)isForward
{
    if( isForward )
        return FilenameTextNavigation::NavigateToNextWord(self.string, location);
    else
        return FilenameTextNavigation::NavigateToPreviousWord(self.string, location);
}

@end

@implementation NCFilenameTextCell
{
    NSTextView* m_FieldEditor;
    bool m_IsBuilding;
}

- (NSTextView *)fieldEditorForView:(NSView *)aControlView
{
    if( !m_FieldEditor ) {
        if( m_IsBuilding == true )
            return nil;
        m_IsBuilding = true;
        
        const auto default_fe = [aControlView.window fieldEditor:true
                                                       forObject:aControlView];
        if( !objc_cast<NSTextView>(default_fe) )
            return nil;
        
        const auto archived_fe = [NSKeyedArchiver archivedDataWithRootObject:default_fe];
        const id copied_fe = [NSKeyedUnarchiver unarchiveObjectWithData:archived_fe];
        m_FieldEditor = objc_cast<NSTextView>(copied_fe);
        [m_FieldEditor.layoutManager replaceTextStorage:[[NCFilenameTextStorage alloc] init]];
    }
    return m_FieldEditor;
}

@end
