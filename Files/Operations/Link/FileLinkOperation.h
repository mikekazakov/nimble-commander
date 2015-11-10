//
//  FileLinkOperation.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../Operation.h"

@class OperationDialogAlert;

@interface FileLinkOperation : Operation

- (id) initWithNewHardLink: (const char*) _source
                  linkname: (const char*) _name;

- (id) initWithNewSymbolinkLink: (const char*) _source
                       linkname: (const char*) _name;

- (id) initWithAlteringOfSymbolicLink: (const char*) _source
                       linkname: (const char*) _name;

- (OperationDialogAlert *)DialogNewHardlinkError:(NSError*)_error;
- (OperationDialogAlert *)DialogNewSymlinkError:(NSError*)_error;
- (OperationDialogAlert *)DialogAlterSymlinkError:(NSError*)_error;

@end
