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
    char buf[65536];
    
    static ssize_t myread(struct archive *a, void *client_data, const void **buff);
    static off_t myseek(struct archive *a, void *client_data, off_t offset, int whence);
    
    void setup(struct archive *a)
    {
        archive_read_set_callback_data(a, this);
        archive_read_set_read_callback(a, myread);
        archive_read_set_seek_callback(a, myseek);
    }
};

struct VFSArchiveDirEntry
{
    std::string name; // optimize
    struct stat st;
};

struct VFSArchiveDir
{
    std::string full_path;          // should alway be with trailing slash
    std::string name_in_parent;     // can be "" only for root directory, full_path will be "/"
    std::deque<VFSArchiveDirEntry> entries;
};
