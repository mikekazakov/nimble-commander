//
//  NSUserDefaults+myColorSupport.h
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaults(myColorSupport)
- (void)setColor:(NSColor *)aColor forKey:(NSString *)aKey;
- (NSColor *)colorForKey:(NSString *)aKey;


- (void)setFont:(NSFont *)aFont forKey:(NSString *)aKey;
- (NSFont *)fontForKey:(NSString *)aKey;


@end
