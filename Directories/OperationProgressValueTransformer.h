//
//  OperationProgressValueTransformer.h
//  Directories
//
//  Created by Pavel Dogurevich on 12.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OperationProgressValueTransformer : NSValueTransformer

+ (Class)transformedValueClass;
+ (BOOL)allowsReverseTransformation;

@end
