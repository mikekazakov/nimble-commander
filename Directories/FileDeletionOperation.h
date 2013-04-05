//
//  FileDeletionOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#include "FlexChainedStringsChunk.h"

enum class FileDeletionOperationType
{
    Invalid,
    MoveToTrash,
    Delete,
    SecureDelete
};

@interface FileDeletionOperation : Operation

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               type:(FileDeletionOperationType)_type
           rootpath:(const char*)_path;


@end
