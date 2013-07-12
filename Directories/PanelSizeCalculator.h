//
//  PanelSizeCalculator.h
//  Directories
//
//  Created by Michael G. Kazakov on 16.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FlexChainedStringsChunk.h"

typedef bool (^PanelDirectorySizeCalculate_CancelChecker)(void);
typedef void (^PanelDirectorySizeCalculate_CompletionHandler)(const char*_dir, unsigned long _size);

void PanelDirectorySizeCalculate( FlexChainedStringsChunk *_dirs, // transfered ownership
                                 const char *_root_path,           // transfered ownership, allocated with malloc
                                 bool _is_dotdot,
                                 PanelDirectorySizeCalculate_CancelChecker _checker,
                                 PanelDirectorySizeCalculate_CompletionHandler _handler);
