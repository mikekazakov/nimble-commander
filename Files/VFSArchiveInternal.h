//
//  VFSArchiveInternal.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <deque>
#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSFile.h"


struct VFSArchiveMediator
{
    std::shared_ptr<VFSFile> file;
    enum {bufsz = 65536 * 4};
    char buf[bufsz];
    
    static ssize_t myread(struct archive *a, void *client_data, const void **buff);
    static off_t myseek(struct archive *a, void *client_data, off_t offset, int whence);
    
    void setup(struct archive *a);
};

struct VFSArchiveSeekCache
{
    struct archive *arc;
    uint32_t uid; // uid of a last read item. if client want to use such cache, their's uid should be bigger than uid
    std::shared_ptr<VFSArchiveMediator> mediator; // includes a valid opened VFSFile;
};

struct VFSArchiveDirEntry
{
    std::string name; // optimize
    struct stat st;
    uint32_t aruid; // unique number inside archive in same order as appearance in archive
};

struct VFSArchiveDir
{
    std::string full_path;          // should alway be with trailing slash
    std::string name_in_parent;     // can be "" only for root directory, full_path will be "/"
    std::deque<VFSArchiveDirEntry> entries;
};
