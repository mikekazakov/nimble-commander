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

- (id) InitWithData:(BigFileViewDataBackend*) _data parent:(BigFileView*) _view;
- (void) OnBufferDecoded;
- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect;

@end
