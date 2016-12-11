//
//  FileLinkNewSymlinkSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>

@interface FileLinkNewSymlinkSheetController : SheetController

@property (readonly) const string& sourcePath;
@property (readonly) const string& linkPath;

- (void)showSheetFor:(NSWindow *)_window
          sourcePath:(const string&)_src_path
            linkPath:(const string&)_link_path
   completionHandler:(void (^)(NSModalResponse returnCode))_handler;

@end
