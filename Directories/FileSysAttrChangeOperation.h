//
//  FileSysAttrChangeOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#import "OperationDialogAlert.h"

struct FileSysAttrAlterCommand;

// FileSysAttrOperation's custom dialog results:
namespace FileSysAttrChangeOperationDialogResult
{
enum
{
    // Skip current and all the following errors.
    SkipAll = OperationDialogResult::Custom,
    // Retry the action.
    Retry   = OperationDialogResult::Custom + 1,
};
}

@interface FileSysAttrChangeOperation : Operation

- (id)initWithCommand:(FileSysAttrAlterCommand*)_command; // passing with ownership, operation will free it on finish
- (NSString *)GetCaption;

- (OperationDialogAlert *)DialogOnChmodError:(int)_error
                                  ForFile:(const char *)_path
                                 WithMode:(mode_t)_mode;

- (OperationDialogAlert *)DialogOnChflagsError:(int)_error
                                   ForFile:(const char*)_path
                                 WithFlags:(uint32_t)_flags;

- (OperationDialogAlert *)DialogOnChownError:(int)_error
                                     ForFile:(const char*)_path
                                         Uid:(uid_t)_uid
                                         Gid:(gid_t)_gid;

@end
