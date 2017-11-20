// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FilenameTextControl.h"

static const auto g_CS = [NSCharacterSet characterSetWithCharactersInString:@".,-_"];

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
    if( self.string.length == 0 )
        return 0;
    
    if( isForward ) {
        if( location == self.string.length )
            return location;
        
        const auto search_range = NSMakeRange(location + 1, self.string.length - location - 1);
        const auto result = [self.string rangeOfCharacterFromSet:g_CS
                                                         options:0
                                                           range:search_range];
        if( result.location != NSNotFound )
            return result.location;
        else
            return self.string.length;
    }
    else {
        if( location == 0 )
            return location;
        
        const auto search_range = NSMakeRange(0, location - 1);
        const auto result = [self.string rangeOfCharacterFromSet:g_CS
                                                         options:NSBackwardsSearch
                                                           range:search_range];
        if( result.location != NSNotFound )
            return result.location + 1;
        else
            return 0;
    }
    
    return [super nextWordFromIndex:location forward:isForward];
}

@end
