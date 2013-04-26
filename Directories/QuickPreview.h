//
//  QuickPreview.h
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PanelView;

@interface QuickPreview : NSObject

+ (void)Show;
+ (void)Hide;
+ (BOOL)IsVisible;
+ (void)PreviewItem:(NSString *)_path sender:(PanelView *)_panel;
+ (void)UpdateData;

@end
