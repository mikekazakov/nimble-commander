//
//  AppStoreRatingsSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 15/02/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppStoreRatingsSheetController : NSWindowController

- (NSModalResponse) runModal;
- (IBAction)OnReview:(id)sender;
- (IBAction)OnRemind:(id)sender;
- (IBAction)OnNo:(id)sender;

@end
