//
//  FileDeletionOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#include "FlexChainedStringsChunk.h"

@class OperationDialogAlert;

namespace FileDeletionOperationDR
{
enum
{
    DeletePermanently = OperationDialogResult::Custom
};
}

enum class FileDeletionOperationType // do not change ordering, there's a raw value persistancy in code
{
    MoveToTrash,
    Delete,
    SecureDelete,
    Invalid
};

@interface FileDeletionOperation : Operation

- (id)initWithFiles:(chained_strings)_files
               type:(FileDeletionOperationType)_type
           rootpath:(const char*)_path;

- (void)Update;

- (OperationDialogAlert *)DialogOnOpendirError:(int)_error ForDir:(const char *)_path;
- (OperationDialogAlert *)DialogOnStatError:(int)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnUnlinkError:(int)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnRmdirError:(int)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnTrashItemError:(NSError *)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnSecureRewriteError:(int)_error ForPath:(const char *)_path;

@end
