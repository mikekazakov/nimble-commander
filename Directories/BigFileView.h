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
- (void) BigFileViewScrolled;       // signal any movements of scroll bar - regardless of reason
                                    // should be used for UI updates only
- (void) BigFileViewScrolledByUser; // signal that position was changed with request of user
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
- (DoubleColor) SelectionBkFillColor;
- (DoubleColor) BackgroundFillColor;

- (int)         Enconding;
- (void)        SetEncoding:(int)_encoding;

- (bool)        WordWrap;
- (void)        SetWordWrap:(bool)_wrapping;

- (int)         ColumnOffset;
- (void)        SetColumnOffset:(int)_offset;

- (BigFileViewModes) Mode;
- (void)        SetMode: (BigFileViewModes) _mode;

- (double)      VerticalScrollPosition;
- (uint64_t)    VerticalPositionInBytes; // whithin all file, now in a window

- (void)        SetSelectionInFile: (CFRange) _selection;   // raw bytes
- (void)        ScrollToSelection;
- (CFRange)     SelectionWithinFile;                        // raw bytes selection
- (CFRange)     SelectionWithinWindow;                      // unichars within a decoded window


@end
