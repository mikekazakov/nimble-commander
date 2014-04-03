//
//  ExternalEditorInfo.h
//  Files
//
//  Created by Michael G. Kazakov on 31.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VFS.h"

@interface ExternalEditorInfo : NSObject<NSCoding>

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *path;
@property (nonatomic) NSString *arguments;
@property (nonatomic) NSString *mask;
@property (nonatomic) bool only_files;
@property (nonatomic) uint64_t max_size;
@property (nonatomic) bool terminal;


- (bool) isValidItem:(const VFSListingItem&)_item;

@end


@interface ExternalEditorsList : NSObject

+ (ExternalEditorsList*) sharedList;

- (ExternalEditorInfo*) FindViableEditorForItem:(const VFSListingItem&)_item;

@end

