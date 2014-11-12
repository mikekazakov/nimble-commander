//
//  VFSArchiveInternal.h
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSFile.h"

struct VFSArchiveMediator
{
    shared_ptr<VFSFile> file;
    enum {bufsz = 65536 * 4};
    char buf[bufsz];
    
    static ssize_t myread(struct archive *a, void *client_data, const void **buff);
    static off_t myseek(struct archive *a, void *client_data, off_t offset, int whence);
    
    void setup(struct archive *a);
};

struct VFSArchiveState
{
    // passes ownership of _arc
    VFSArchiveState( const VFSFilePtr &_file, struct archive *_arc );
    ~VFSArchiveState();
    
    inline struct archive          *Archive() { return m_Archive; }
    inline struct archive_entry    *Entry() { return m_Entry; }
    inline uint32_t                 UID() { return m_UID; }
    inline bool                     Consumed() { return m_Consumed; }
    
    // assumes that this call is in  archive_read_next_header cycle. sets consumed flag to false
    void SetEntry(struct archive_entry *_e, uint32_t _uid);
    inline void ConsumeEntry() { m_Consumed = true; }
    
    // libarchive API wrapping
    // any error codes are raw libarchive one, not converted to VFSError
    int Open();
    int Errno();
    
private:
    VFSArchiveState(const VFSArchiveState&) = delete;
    void Setup();
    static ssize_t myread(struct archive *a, void *client_data, const void **buff);
    static off_t myseek(struct archive *a, void *client_data, off_t offset, int whence);

    enum {BufferSize = 65536 * 4};
    VFSFilePtr              m_File;
    struct archive         *m_Archive = nil;
    struct archive_entry   *m_Entry = nil; // entry for current archive state
    uint32_t                m_UID = 0;
    bool                    m_Consumed = false;
    char                    m_Buf[BufferSize];
};

struct VFSArchiveDirEntry
{
    string name; // optimize
    struct stat st;
    uint32_t aruid; // unique number inside archive in same order as appearance in archive
};

struct VFSArchiveDir
{
    string full_path;          // should alway be with trailing slash
    string name_in_parent;     // can be "" only for root directory, full_path will be "/"
    deque<VFSArchiveDirEntry> entries;
};
