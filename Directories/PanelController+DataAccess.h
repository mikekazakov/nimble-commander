//
//  PanelController+DataAccess.h
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (DataAccess)

- (bool) GetCurrentFocusedEntryFilename:(char*) _filename; // return false if there's no focused entry (invalid state)
- (bool) GetCurrentFocusedEntryFilePathRelativeToHost:(char*) _file_path; // return false if there's no focused entry (invalid state)

@end
