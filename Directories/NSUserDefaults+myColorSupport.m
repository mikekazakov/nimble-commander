//
//  NSUserDefaults+myColorSupport.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "NSUserDefaults+myColorSupport.h"

@implementation NSUserDefaults(myColorSupport)

- (void)setColor:(NSColor *)aColor forKey:(NSString *)aKey
{
    NSData *theData=[NSArchiver archivedDataWithRootObject:aColor];
    [self setObject:theData forKey:aKey];
}

- (NSColor *)colorForKey:(NSString *)aKey
{
    NSColor *theColor=nil;
    NSData *theData=[self dataForKey:aKey];
    if (theData != nil)
        theColor=(NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
    return theColor;
}

- (void)setFont:(NSFont *)aFont forKey:(NSString *)aKey
{
    NSData *theData=[NSArchiver archivedDataWithRootObject:aFont];
    [self setObject:theData forKey:aKey];
}

- (NSFont *)fontForKey:(NSString *)aKey
{
    NSFont *theFont=nil;
    NSData *theData=[self dataForKey:aKey];
    if (theData != nil)
        theFont=(NSFont *)[NSUnarchiver unarchiveObjectWithData:theData];
    return theFont;    
}


@end