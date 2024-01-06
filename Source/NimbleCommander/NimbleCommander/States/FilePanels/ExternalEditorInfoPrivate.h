// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class ExternalEditorStartupInfo;

@interface ExternalEditorInfo : NSObject<NSCoding, NSCopying>

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *path;
@property (nonatomic) NSString *arguments;
@property (nonatomic) NSString *mask;
@property (nonatomic) bool only_files;
@property (nonatomic) uint64_t max_size;
@property (nonatomic) bool terminal;


//- (bool) isValidItem:(const VFSListingItem&)_item;

/**
 * Returns arguments in UTF8 form where %% appearances are changed to specified file path.
 * Treat empty arguments as @"%%" string. _path is escaped with backward slashes.
 */
//- (string) substituteFileName:(const string &)_path;

- (std::shared_ptr<ExternalEditorStartupInfo>) toStartupInfo;

@end
