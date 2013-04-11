//
//  OperationProgressValueTransformer.m
//  Directories
//
//  Created by Pavel Dogurevich on 12.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationProgressValueTransformer.h"

@implementation OperationProgressValueTransformer

+ (Class)transformedValueClass
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    if (value == nil) return nil;
    
    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(floatValue)])
    {
        return [NSNumber numberWithFloat:100*[value floatValue]];
    }
    
    [NSException raise: NSInternalInconsistencyException
                format: @"Value (%@) does not respond to -floatValue.",
        [value class]];
    
    return nil;
}

@end
