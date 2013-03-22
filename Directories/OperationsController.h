//
//  OperationsController.h
//  Directories
//
//  Created by Pavel Dogurevich on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Operation.h"

@interface OperationsController : NSObject

-(void)AddOperation:(Operation *)_op;

-(void)Update;

@end
