//
//  FileDeletionOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#import "VFS.h"

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

- (id)initWithFiles:(vector<string>&&)_files
               type:(FileDeletionOperationType)_type
                dir:(const string&)_path;

// VFS deletion can be only "delete", not "moving to trash" or "secure delete"
- (id)initWithFiles:(vector<string>&&)_files
                dir:(const string&)_path
                 at:(const VFSHostPtr&) _host;

- (void)Update;

- (OperationDialogAlert *)DialogOnOpendirError:(NSError*)_error ForDir:(const char *)_path;
- (OperationDialogAlert *)DialogOnUnlinkError:(NSError*)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnRmdirError:(NSError*)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnTrashItemError:(NSError *)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnSecureRewriteError:(NSError *)_error ForPath:(const char *)_path;
@end
