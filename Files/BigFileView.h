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
{ // changing this values may cause stored history corruption
    Text = 0,
    Hex  = 1
};

@protocol BigFileViewDelegateProtocol <NSObject>
@optional
- (void) BigFileViewScrolled;       // signal any movements of scroll bar - regardless of reason
                                    // should be used for UI updates only
- (void) BigFileViewScrolledByUser; // signal that position was changed with request of user
@end

@interface BigFileView : NSView

- (void) SetFile:(FileWindow*) _file;
- (void) SetKnownFile:(FileWindow*) _file encoding:(int)_encoding mode:(BigFileViewModes)_mode;

- (void) RequestWindowMovementAt: (uint64_t) _pos;
- (void) UpdateVerticalScroll: (double) _pos prop:(double)prop;

// appearance section
- (CTFontRef)   TextFont;
- (CGColorRef)  TextForegroundColor;
- (DoubleColor) SelectionBkFillColor;
- (DoubleColor) BackgroundFillColor;
- (bool)        ShouldAntialias;
- (bool)        ShouldSmoothFonts;

// Frontend section
- (int)         Enconding;
- (void)        setEncoding:(int)_encoding;

- (bool)        WordWrap;
- (void)        setWordWrap:(bool)_wrapping;

- (BigFileViewModes) Mode;
- (void)        setMode: (BigFileViewModes) _mode;

- (double)      VerticalScrollPosition;
- (uint64_t)    VerticalPositionInBytes; // whithin all file, now in a window
- (void)        SetVerticalPositionInBytes:(uint64_t) _pos;

// raw bytes in whole file
- (CFRange)     SelectionInFile;
- (void)        SetSelectionInFile: (CFRange) _selection;
- (void)        ScrollToSelection;
- (CFRange)     SelectionWithinWindow;                      // bytes within a decoded window
- (CFRange)     SelectionWithinWindowUnichars;              // unichars within a decoded window

@property (nonatomic, weak) id<BigFileViewDelegateProtocol> delegate;
@end
