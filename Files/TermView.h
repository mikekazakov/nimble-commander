//
//  TermView.h
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

class TermScreen;
class TermParser;
class FontCache;

@interface TermView : NSView


- (FontCache*) FontCache;

- (void) AttachToScreen:(TermScreen*)_scr;
- (void) AttachToParser:(TermParser*)_par;
- (void) setRawTaskFeed:(void(^)(const void* _d, int _sz))_feed;

- (void) adjustSizes:(bool)_mandatory; // implicitly calls scrollToBottom when full height changes
- (void) scrollToBottom;

@end
