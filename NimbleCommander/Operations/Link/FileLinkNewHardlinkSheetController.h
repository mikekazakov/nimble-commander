//
//  FileLinkNewHardlinkSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>

@interface FileLinkNewHardlinkSheetController : SheetController

@property (readonly) const string &result;

- (void)showSheetFor:(NSWindow *)_window
      withSourceName:(const string&)_src
   completionHandler:(void (^)(NSModalResponse returnCode))_handler;

@end
