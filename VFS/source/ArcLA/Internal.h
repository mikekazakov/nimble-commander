// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>
#include <VFS/VFSFile.h>
#include <deque>

namespace nc::vfs::arc {

struct Mediator
{
    std::shared_ptr<VFSFile> file;
    enum {bufsz = 65536 * 4};
    char buf[bufsz];
    
    static ssize_t myread(struct archive *a, void *client_data, const void **buff);
    static off_t myseek(struct archive *a, void *client_data, off_t offset, int whence);
    
    void setup(struct archive *a);
};

struct State
{
    // passes ownership of _arc
    State( const VFSFilePtr &_file, struct archive *_arc );
    ~State();
    
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
    State(const State&) = delete;
    void Setup();
    static ssize_t myread(struct archive *a, void *client_data, const void **buff);
    static off_t myseek(struct archive *a, void *client_data, off_t offset, int whence);

    enum {BufferSize = 65536 * 4};
    VFSFilePtr              m_File;
    struct archive         *m_Archive = nullptr;
    struct archive_entry   *m_Entry = nullptr; // entry for current archive state
    uint32_t                m_UID = 0;
    bool                    m_Consumed = false;
    char                    m_Buf[BufferSize];
};

struct DirEntry
{
    std::string name; // optimize
    struct stat st;
    uint32_t aruid; // unique number inside archive in same order as appearance in archive
};

struct Dir
{
    std::string full_path;          // should alway be with trailing slash
    std::string name_in_parent;     // can be "" only for root directory, full_path will be "/"
    uint64_t content_size = 0;
    std::deque<DirEntry> entries;
};

}
