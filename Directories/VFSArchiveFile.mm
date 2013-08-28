//
//  VFSArchiveFile.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSArchiveFile.h"
#import "VFSArchiveInternal.h"


VFSArchiveFile::VFSArchiveFile(const char* _relative_path, std::shared_ptr<VFSArchiveHost> _host):
    VFSFile(_relative_path, _host),
    m_Arc(0)
{
}

VFSArchiveFile::~VFSArchiveFile()
{
    Close();
}

int VFSArchiveFile::Open(int _open_flags)
{
    if( strlen(RelativePath()) < 2 || RelativePath()[0] != '/' )
        return VFSError::NotFound;
    
    m_ArFile = std::dynamic_pointer_cast<VFSArchiveHost>(Host())->ArFile()->Clone();
    int res;
    
    res = m_ArFile->Open(VFSFile::OF_Read);
    if(res < 0)
        return res;
    
    m_Mediator = std::make_shared<VFSArchiveMediator>();
    m_Mediator->file = m_ArFile;
    
    // open for read-only now
    m_Arc = archive_read_new();
    archive_read_support_filter_all(m_Arc);
    archive_read_support_format_all(m_Arc);
    m_Mediator->setup(m_Arc);

    res = archive_read_open1(m_Arc);
    if(res < 0)
    {
        Close();
        return -1; // TODO right error codes
    }
    bool found = false;
    struct archive_entry *entry;
    char path[1024];
    strcpy(path, RelativePath()+1); // skip first symbol, which is '/'
    while (archive_read_next_header(m_Arc, &entry) == ARCHIVE_OK)
        // consider case-insensitive comparison later
        if(strcmp(path, archive_entry_pathname(entry)) == 0)
        {
            found = true;
            break;
        }
    
    if(!found)
    {
        Close();
        return VFSError::NotFound;
    }
        
    m_Position = 0;
    m_Size = archive_entry_size(entry);

    return VFSError::Ok;
}

bool VFSArchiveFile::IsOpened() const
{
    return m_Arc != 0;
}

int VFSArchiveFile::Close()
{
    if(m_Arc != 0)
    {
        archive_read_free(m_Arc);
        m_Arc = 0;
        m_Mediator.reset();
        m_ArFile.reset();
    }
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSArchiveFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

ssize_t VFSArchiveFile::Pos() const
{
    if(!m_Arc)
        return VFSError::InvalidCall;
    return m_Position;
}

ssize_t VFSArchiveFile::Size() const
{
    if(!m_Arc)
        return VFSError::InvalidCall;
    return m_Size;
}

bool VFSArchiveFile::Eof() const
{
    if(!m_Arc)
        return true;
    return m_Position == m_Size;
}

ssize_t VFSArchiveFile::Read(void *_buf, size_t _size)
{
    if(m_Arc < 0) return VFSError::InvalidCall;
    if(Eof())     return 0;

    ssize_t size = archive_read_data(m_Arc, _buf, _size);
    if(size < 0)
    {
        // TODO: libarchive error - convert it into our errors
        return -1;
    }
    
    return size;
}

