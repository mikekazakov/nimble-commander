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

enum class FileDeletionOperationType
{
    MoveToTrash,
    Delete,
    SecureDelete,
    Invalid
};

@interface FileDeletionOperation : Operation

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
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
