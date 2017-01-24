//
//  ExternalEditorInfo.h
//  Files
//
//  Created by Michael G. Kazakov on 31.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <VFS/VFS.h>

@interface ExternalEditorInfo : NSObject<NSCoding, NSCopying>

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *path;
@property (nonatomic) NSString *arguments;
@property (nonatomic) NSString *mask;
@property (nonatomic) bool only_files;
@property (nonatomic) uint64_t max_size;
@property (nonatomic) bool terminal;


- (bool) isValidItem:(const VFSListingItem&)_item;

/**
 * Returns arguments in UTF8 form where %% appearances are changed to specified file path.
 * Treat empty arguments as @"%%" string. _path is escaped with backward slashes.
 */
- (string) substituteFileName:(const string &)_path;

@end


@interface ExternalEditorsList : NSObject

+ (ExternalEditorsList*) sharedList;

- (ExternalEditorInfo*) FindViableEditorForItem:(const VFSListingItem&)_item;
- (NSMutableArray*) Editors;
- (void) setEditors:(NSMutableArray*)_editors;

@end

