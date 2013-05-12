//
//  BigFileViewProtocol.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <stdint.h>

//class FileWindow;
@class BigFileView;

@protocol BigFileViewProtocol <NSObject>

// initialization
- (id) InitWithWindow: (const UniChar*) _unichar_window
    offsets:(const uint32_t*) _unichar_indeces
    size: (size_t) _unichars_amount // unichars, not bytes (x2)
    parent: (BigFileView*) _view;

// event handling
- (void) OnBufferDecoded: (size_t) _new_size; // unichars, not bytes (x2)
- (void) OnUpArrow;
- (void) OnDownArrow;
//- (void) OnLeftArrow;
//- (void) OnRightArrow;
- (void) OnPageDown;
- (void) OnPageUp;

// drawing
- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect;

@end
