//
//  TextView.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 05.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "FileWindow.h"
#include "Encodings.h"


@interface BigFileView : NSView

- (void) SetFile:(FileWindow*) _file;

// data access section
- (const void*) RawWindow;
- (uint64_t)    RawWindowSize;
- (uint64_t)    RawWindowPosition;
- (uint64_t)    FullSize;
- (void) RequestWindowMovementAt: (uint64_t) _pos;
- (void) UpdateVerticalScroll: (double) _pos prop:(double)prop;

// appearance section
- (CTFontRef)   TextFont;
- (CGColorRef)  TextForegroundColor;




- (IBAction)ToggleTextView:(id)sender;
- (IBAction)ToggleHexView:(id)sender;

@end
