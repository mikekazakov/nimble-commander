//
//  FeatureNotAvailableWindowController.h
//  Files
//
//  Created by Michael G. Kazakov on 01/12/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

@interface FeatureNotAvailableWindowController : NSWindowController
@property (strong) IBOutlet NSTextView *textView;
- (IBAction)OnClose:(id)sender;

@end
