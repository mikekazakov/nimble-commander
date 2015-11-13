//
//  OperationsSummaryView.h
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Operation;

@interface GenericOperationView : NSView

@property (readonly) NSTextField *Caption;
@property (readonly) NSProgressIndicator *Progress;
@property (readonly) NSButton *PauseButton;
@property (readonly) NSButton *StopButton;
@property (readonly) NSButton *DialogButton;

@end
