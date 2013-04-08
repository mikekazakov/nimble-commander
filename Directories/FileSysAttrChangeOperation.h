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

@interface FileSysAttrChangeOperation : Operation

enum
{
    // Custom dialog results:
    // Skip this and all the following errors.
    FileSysAttrChangeOperationDialogSkipAll = OperationDialogResultCustom
};

- (id)initWithCommand:(FileSysAttrAlterCommand*)_command; // passing with ownership, operation will free it on finish
- (NSString *)GetCaption;

- (OperationDialogAlert *)DialogChmodError:(int)_error
                                  ForFile:(const char *)_path
                                 WithMode:(mode_t)_mode;

@end
