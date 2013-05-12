//
//  BigFileViewHex.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BigFileViewProtocol.h"

@interface BigFileViewHex : NSObject<BigFileViewProtocol>

- (id) InitWithWindow:(const UniChar*) _unichar_window
              offsets:(const uint32_t*) _unichar_indeces
                 size:(size_t) _unichars_amount // unichars, not bytes (x2)
               parent:(BigFileView*) _view;




@end
