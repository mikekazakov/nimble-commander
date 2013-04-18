//
//  PanelSizeCalculator.h
//  Directories
//
//  Created by Michael G. Kazakov on 16.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FlexChainedStringsChunk.h"

@class PanelController;

typedef bool (^PanelDirectorySizeCalculate_CancelChecker)(void);

void PanelDirectorySizeCalculate( FlexChainedStringsChunk *_dirs, // transfered ownership
                                 const char *_root_path,           // transfered ownership, allocated with malloc
                                 PanelController *_panel,
                                 PanelDirectorySizeCalculate_CancelChecker _checker);

