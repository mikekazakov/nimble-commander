//
//  FileSysAttrChangeOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
struct FileSysAttrAlterCommand;

@interface FileSysAttrChangeOperation : Operation

- (id)initWithCommand:(FileSysAttrAlterCommand*)_command; // passing with ownership, operation will free it on finish

@end
