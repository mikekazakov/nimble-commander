//
//  FilePanelOverlappedTerminal.h
//  Files
//
//  Created by Michael G. Kazakov on 16/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FilePanelOverlappedTerminal : NSView

- (double) bottomGapForLines:(int)_lines_amount;
- (int) totalScreenLines;

@end
