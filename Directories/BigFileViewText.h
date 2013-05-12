//
//  BigFileViewText.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BigFileViewProtocol.h"

@interface BigFileViewText : NSObject<BigFileViewProtocol>

- (id) InitWithWindow:(const UniChar*) _unichar_window
                offsets:(const uint32_t*) _unichar_indeces
                   size:(size_t) _unichars_amount // unichars, not bytes (x2)
                 parent:(BigFileView*) _view;

- (void) OnBufferDecoded: (size_t) _new_size; // unichars, not bytes (x2)

- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect;

@end
