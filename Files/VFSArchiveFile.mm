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
#import "AppleDoubleEA.h"

VFSArchiveFile::VFSArchiveFile(const char* _relative_path, shared_ptr<VFSArchiveHost> _host):
    VFSFile(_relative_path, _host),
    m_Arc(0),
    m_ShouldCommitSC(0),
    m_UID(0),
    m_Entry(0),
    m_EA(0),
    m_EACount(0)
{
}

VFSArchiveFile::~VFSArchiveFile()
{
    Close();
}

int VFSArchiveFile::Open(int _open_flags)
{
    if( strlen(RelativePath()) < 2 || RelativePath()[0] != '/' )
        return SetLastError(VFSError::NotFound);
    
    if(_open_flags & VFSFile::OF_Write)
        return SetLastError(VFSError::NotSupported); // ArchiveFile is Read-Only
    
    auto host = dynamic_pointer_cast<VFSArchiveHost>(Host());
    
    uint32_t myuid = host->ItemUID(RelativePath());
    if(myuid == 0)
        return SetLastError(VFSError::NotFound);
    m_UID = myuid;
    
//    unsigned long scuid = host->SeekCachePosition();
    auto sc = host->SeekCache(myuid);
    
//    if(scuid == 0 || scuid >= myuid)
    if(!sc.get())
    {
        m_ArFile = dynamic_pointer_cast<VFSArchiveHost>(Host())->ArFile()->Clone();
        int res;
    
        res = m_ArFile->Open(VFSFile::OF_Read);
        if(res < 0)
            return SetLastError(res);
    
        m_Mediator = make_shared<VFSArchiveMediator>();
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
            return SetLastError(VFSError::FromLibarchive(archive_errno(m_Arc)));
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
            return SetLastError(VFSError::NotFound);
        }
        
        m_Entry = entry;
        m_Position = 0;
        m_Size = archive_entry_size(entry);
        m_ShouldCommitSC = true;
        
        // read and parse metadata(xattrs) if any
        size_t s;
        m_EA = ExtractEAFromAppleDouble(archive_entry_mac_metadata(m_Entry, &s), s, &m_EACount);

        return VFSError::Ok;
    }
    else
    {
        bool found = false;
        struct archive_entry *entry;
        char path[1024];
        strcpy(path, RelativePath()+1); // skip first symbol, which is '/'
        while (archive_read_next_header(sc->arc, &entry) == ARCHIVE_OK)
            // consider case-insensitive comparison later
            if(strcmp(path, archive_entry_pathname(entry)) == 0)
            {
                found = true;
                break;
            }

        if(!found)
        {
            archive_read_free(sc->arc);
            return SetLastError(VFSError::NotFound);
        }

        m_Entry = entry;
        m_Arc = sc->arc;
        m_ArFile = sc->mediator->file;
        m_Mediator = sc->mediator;
        m_Position = 0;
        m_Size = archive_entry_size(entry);
        m_ShouldCommitSC = true;

        // read and parse metadata(xattrs) if any
        size_t s;
        m_EA = ExtractEAFromAppleDouble(archive_entry_mac_metadata(m_Entry, &s), s, &m_EACount);
        
        return VFSError::Ok;
    }
}

bool VFSArchiveFile::IsOpened() const
{
    return m_Arc != 0;
}

int VFSArchiveFile::Close()
{    
    if(m_Arc != 0)
    {
        if(!m_ShouldCommitSC)
        {
            archive_read_free(m_Arc);
            m_Arc = 0;
            m_Mediator.reset();
            m_ArFile.reset();
        }
        else
        {
            // transfer ownership of handles to Host
            assert(m_UID);
            shared_ptr<VFSArchiveSeekCache> sc = make_shared<VFSArchiveSeekCache>();
            sc->uid = m_UID;
            sc->arc = m_Arc;
            sc->mediator = m_Mediator;
            dynamic_pointer_cast<VFSArchiveHost>(Host())->CommitSeekCache(sc);
            m_Arc = 0;
            m_Mediator.reset();
            m_ArFile.reset();
        }
    }
    
    m_Entry = 0;
    m_EACount = 0;
    free(m_EA);
    m_EA = 0;
    
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSArchiveFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

ssize_t VFSArchiveFile::Pos() const
{
    if(!m_Arc)
        return SetLastError(VFSError::InvalidCall);
    return m_Position;
}

ssize_t VFSArchiveFile::Size() const
{
    if(!m_Arc)
        return SetLastError(VFSError::InvalidCall);
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
    if(m_Arc == 0) return SetLastError(VFSError::InvalidCall);
    if(Eof())     return 0;
    
    assert(_buf != 0);

    ssize_t size = archive_read_data(m_Arc, _buf, _size);
    if(size < 0)
    {
        // TODO: libarchive error - convert it into our errors
        printf("libarchive error: %s\n", archive_error_string(m_Arc));
//        return -1;
        return SetLastError(VFSError::FromLibarchive(archive_errno(m_Arc)));
    }
    
    m_Position += size;
    
    return size;
}

unsigned VFSArchiveFile::XAttrCount() const
{
    return (unsigned)m_EACount;
}

void VFSArchiveFile::XAttrIterateNames( bool (^_handler)(const char* _xattr_name) ) const
{
    if(!_handler || m_EACount == 0)
        return;
    assert(m_EA != 0);
    
    for(int i = 0; i < m_EACount; ++i)
        if( !_handler(m_EA[i].name) )
            break;
}

ssize_t VFSArchiveFile::XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const
{
    if(!m_Arc || !_xattr_name)
        return SetLastError(VFSError::InvalidCall);
    
    for(int i = 0; i < m_EACount; ++i)
        if(strcmp(m_EA[i].name, _xattr_name) == 0)
        {
            if(_buffer == 0)
                return m_EA[i].data_sz;
    
            size_t sz = min(m_EA[i].data_sz, (uint32_t)_buf_size);
            memcpy(_buffer, m_EA[i].data, sz);
            return sz;
        }

    return SetLastError(VFSError::NotFound);
}
