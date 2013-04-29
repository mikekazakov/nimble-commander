//
//  QuickPreview.m
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "QuickPreview.h"
#import "PanelView.h"

#import <Quartz/Quartz.h>


@interface QuickPreviewItem : NSObject <QLPreviewItem>
@property NSURL *previewItemURL;
@end

@implementation QuickPreviewItem
@end

///////////////////////////////////////////////////////////////////////////////////////////////
@interface QuickPreviewData : NSObject <QLPreviewPanelDataSource>
- (void)UpdateItem:(NSURL *)_path;
@end

@implementation QuickPreviewData
{
    QuickPreviewItem *m_Item;
}

- (id)init
{
    self = [super init];
    if (self) m_Item = [[QuickPreviewItem alloc] init];
    return self;
}

- (void)UpdateItem:(NSURL *)_path
{
    if ([_path isEqual:m_Item.previewItemURL]) return;
    
    m_Item = [[QuickPreviewItem alloc] init];
    m_Item.previewItemURL = _path;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return 1;
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    assert(index == 0);
    return m_Item;
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////
@implementation QuickPreview
static QuickPreviewData *m_Data;

+ (void)initialize
{
    m_Data = [[QuickPreviewData alloc] init];
}

+ (void)Show
{
    [[QLPreviewPanel sharedPreviewPanel] orderFront:nil];
    [[QLPreviewPanel sharedPreviewPanel] setDataSource:m_Data];
}

+ (void)Hide
{
    [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
}

+ (BOOL)IsVisible
{
    return [[QLPreviewPanel sharedPreviewPanel] isVisible];
}

+ (void)PreviewItem:(NSString *)_path sender:(PanelView *)_panel
{
    NSWindow *window = [_panel window];
    if (![window isKeyWindow]) return;
    
    [m_Data UpdateItem:[NSURL fileURLWithPath:_path]];
    [[QLPreviewPanel sharedPreviewPanel] reloadData];
}

+ (void)UpdateData
{
    [QLPreviewPanel sharedPreviewPanel].dataSource = m_Data;
}

@end
