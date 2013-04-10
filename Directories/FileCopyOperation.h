//
//  FileCopyOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#import "FlexChainedStringsChunk.h"


@interface FileCopyOperation : Operation

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               root:(const char*)_root
               dest:(const char*)_dest;


@end
