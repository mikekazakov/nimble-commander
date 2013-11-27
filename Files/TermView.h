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

@interface TermView : NSView

- (int) SymbWidth;
- (int) SymbHeight;

- (void) AttachToScreen:(TermScreen*)_scr;
- (void) AttachToParser:(TermParser*)_par;

- (void)adjustSizes;

@end
