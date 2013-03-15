//
//  JobView.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <Cocoa/Cocoa.h>
class JobData;

@interface JobView : NSView

- (void) SetJobData:(JobData*)_data;
- (void) UpdateByTimer;

@end
