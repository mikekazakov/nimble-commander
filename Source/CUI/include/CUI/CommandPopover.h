// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>

@interface NCCommandPopoverItem : NSObject

- (instancetype _Nonnull)init;

+ (instancetype _Nonnull)separatorItem;

+ (instancetype _Nonnull)sectionHeaderWithTitle:(NSString *_Nonnull)_title;

@property(nonatomic, copy) NSString *_Nonnull title;

@property(nonatomic, nullable, copy) NSString *toolTip;

@property(nonatomic, nullable, strong) NSImage *image;

@property(nonatomic, nullable, weak) id target;

@property(nonatomic, nullable) SEL action;

@property(nonatomic) NSInteger tag;

@property(nonatomic, nullable, strong) id representedObject;

@property(nonatomic, readonly) bool separatorItem;

@property(nonatomic, readonly) bool sectionHeader;

@end

@interface NCCommandPopover : NSPopover

- (instancetype _Nonnull)init NS_UNAVAILABLE;
- (instancetype _Nonnull)initWithTitle:(NSString *_Nonnull)_title;

- (void)addItem:(NCCommandPopoverItem *_Nonnull)_newItem;

// TODO: add a dedicated show... method

@end
