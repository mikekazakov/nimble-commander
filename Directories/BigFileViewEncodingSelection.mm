//
//  BigFileViewEncodingSelection.m
//  Files
//
//  Created by Michael G. Kazakov on 21.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "BigFileViewEncodingSelection.h"
#import "Encodings.h"

static NSMutableDictionary *EncodingToDict(int _encoding, NSString *_name)
{
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
        _name, @"name",
        [NSNumber numberWithInt:_encoding], @"code",
        nil
    ];
}

@implementation BigFileViewEncodingSelection
{
    int m_OriginalEncoding;
}

- (id) init
{
    self = [super initWithWindowNibName:@"BigFileViewEncodingSelection"];
    if(!self)
        return self;

    m_OriginalEncoding = ENCODING_MACOS_ROMAN_WESTERN;
            
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self.Encodings addObject:EncodingToDict(ENCODING_MACOS_ROMAN_WESTERN, @"Western (Mac OS Roman)")];
    [self.Encodings addObject:EncodingToDict(ENCODING_OEM866, @"OEM 866 (DOS)")];
    [self.Encodings addObject:EncodingToDict(ENCODING_WIN1251, @"Windows 1251")];
    [self.Encodings addObject:EncodingToDict(ENCODING_UTF8, @"UTF-8")];    
    
    for(NSMutableDictionary *d in [self.Encodings arrangedObjects])
        if([(NSNumber*)[d objectForKey:@"code"] intValue] == m_OriginalEncoding)
        {
            [self.Encodings setSelectionIndex: [[self.Encodings arrangedObjects] indexOfObject:d]];
            break;
        }    
}

- (void)windowWillClose:(NSNotification *)notification
{
    NSUInteger sel = [self.Encodings selectionIndex];
    if(sel != NSNotFound)
    {
        NSMutableDictionary *m =  [(NSArray *)[self.Encodings arrangedObjects] objectAtIndex:sel];
        NSNumber *i = [m objectForKey:@"code"];
        [NSApp stopModalWithCode:[i intValue]];
    }
    else
    {
        [NSApp stopModalWithCode:ENCODING_INVALID];
    }
}

- (void) SetCurrentEncoding:(int)_encoding
{
    m_OriginalEncoding = _encoding;
}

@end
