//
//  BigFileViewEncodingSelection.h
//  Files
//
//  Created by Michael G. Kazakov on 21.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BigFileViewEncodingSelection : NSWindowController
@property (strong) IBOutlet NSArrayController *Encodings;
- (void) SetCurrentEncoding:(int)_encoding;
@end
