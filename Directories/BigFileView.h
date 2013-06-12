//
//  TextView.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 05.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FileWindow.h"
#import "Encodings.h"
#import "OrthodoxMonospace.h"

enum class BigFileViewModes
{
    Text,
    Hex
};

@protocol BigFileViewDelegateProtocol <NSObject>
@optional
- (void) BigFileViewScrolled;
@end

@interface BigFileView : NSView

- (void) SetFile:(FileWindow*) _file;
- (void) SetDelegate:(id<BigFileViewDelegateProtocol>) _delegate;
- (void) DoClose;

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
- (DoubleColor) BackgroundFillColor;

- (int)         Enconding;
- (void)        SetEncoding:(int)_encoding;

- (bool)        WordWrap;
- (void)        SetWordWrap:(bool)_wrapping;

- (BigFileViewModes) Mode;
- (void)        SetMode: (BigFileViewModes) _mode;

- (double)      VerticalScrollPosition;

@end
