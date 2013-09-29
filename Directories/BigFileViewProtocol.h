//
//  BigFileViewProtocol.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <stdint.h>
#import "BigFileViewDataBackend.h"


@class BigFileView;

@protocol BigFileViewProtocol <NSObject>

// initialization
- (id) InitWithData:(BigFileViewDataBackend*) _data parent:(BigFileView*) _view;

// information
- (uint32_t) GetOffsetWithinWindow; // offset of a first visible symbol (+/-)

// event handling
- (void) OnBufferDecoded;
- (void) OnUpArrow;
- (void) OnDownArrow;
- (void) OnPageDown;
- (void) OnPageUp;
- (void) OnFrameChanged;
- (void) OnFontSettingsChanged; // may need to rebuild layout here

- (void) MoveOffsetWithinWindow: (uint32_t)_offset; // request to move visual offset to an approximate amount
                                                    // now moving window itself

- (void) ScrollToByteOffset: (uint64_t)_offset;     // scroll to specified offset, moving window if needed


- (void) HandleVerticalScroll: (double) _pos; // move file window if needed

// drawing
- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect;

@optional
- (void) OnLeftArrow;
- (void) OnRightArrow;
- (void) OnMouseDown:(NSEvent *)_event;
- (void) OnWordWrappingChanged;


@end
