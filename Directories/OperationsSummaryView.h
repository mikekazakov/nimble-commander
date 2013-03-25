//
//  OperationsSummaryView.h
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface OperationsSummaryView : NSView

@property (weak) IBOutlet NSButton *PauseButton;
@property (weak) IBOutlet NSButton *StopButton;
@property (weak) IBOutlet NSButton *OperationsCountButton;

@end
