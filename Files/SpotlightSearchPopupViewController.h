//
//  SpotlightSearchPopupViewController.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 4/15/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#pragma once

@interface SpotlightSearchPopupViewController : NSViewController<NSPopoverDelegate>

@property (nonatomic) function<void(const string&)> handler;

@end
