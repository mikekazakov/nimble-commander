// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include "Host.h"
#include "Internals.h"

namespace nc::vfs::unrar {

File::File(const char* _relative_path, std::shared_ptr<UnRARHost> _host):
    VFSFile(_relative_path, _host),
    m_UnpackThread(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)),
    m_UnpackBuffer(new uint8_t[m_UnpackBufferDefaultCapacity]),
    m_UnpackBufferCapacity(m_UnpackBufferDefaultCapacity)
{
}

File::~File()
{
    Close();
    assert(m_ExtractionRunning == false);
}

int File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if( strlen(Path()) < 2 || Path()[0] != '/' )
        return SetLastError(VFSError::NotFound);
    
    if(_open_flags & VFSFlags::OF_Write)
        return SetLastError(VFSError::NotSupported); // UnRAR is Read-Only
    
    auto rar_host = std::dynamic_pointer_cast<UnRARHost>(Host());
    auto entry = rar_host->FindEntry(Path());
    if(entry == 0)
        return SetLastError(VFSError::NotFound);
    
    if(entry->isdir)
        return SetLastError(VFSError::FromErrno(EISDIR));

    m_Entry = entry;
    m_Archive = rar_host->SeekCache(entry->uuid);
    
    if(!m_Archive)
        return SetLastError(VFSError::GenericError);
    
    RARHeaderDataEx header;
    int read_head_ret = 0, skip_file_ret = 0;
    while((read_head_ret = RARReadHeaderEx(m_Archive->rar_handle, &header)) == 0)
    {
        if(m_Entry->rar_name == header.FileName)
        {
            break;
        }
        else if ((skip_file_ret = RARProcessFile(m_Archive->rar_handle, RAR_SKIP, NULL, NULL)) != 0)
        {
            break;
        }
    }
    
    if(read_head_ret != 0)
        return SetLastError(VFSError::NotFound);

    if(skip_file_ret != 0)
        return SetLastError(VFSError::NotFound); // bad data?
    
    m_ConsumeSemaphore      = dispatch_semaphore_create(0);
    m_FinishUnpackSemaphore = dispatch_semaphore_create(0);
    m_UnpackSemaphore       = dispatch_semaphore_create(0);
    
    m_ExtractionRunning = true;
    dispatch_async(m_UnpackThread, ^{
        // hold shared_this in this block.
         RARSetCallback(m_Archive->rar_handle, ProcessRAR, (long)this);
         m_RarError = RARProcessFile(m_Archive->rar_handle, RAR_TEST, NULL, NULL);
        if(m_RarError != 0)
             std::cerr << "RARProcessFile returned " << m_RarError << std::endl;

         m_ExtractionRunning = false;
         dispatch_semaphore_signal(m_FinishUnpackSemaphore);
    });
    
    return 0;
}

bool File::IsOpened() const
{
    return m_Archive.get() != nullptr;
}

int File::Close()
{
    m_ExitUnpacking = true;
    
    if(m_FinishUnpackSemaphore) {
        dispatch_semaphore_signal(m_UnpackSemaphore);
        dispatch_semaphore_wait(m_FinishUnpackSemaphore, DISPATCH_TIME_FOREVER);
        //dispatch_release(m_FinishUnpackSemaphore);
        m_FinishUnpackSemaphore = 0;
    }
    
    assert(m_ExtractionRunning == false);
    
    if(m_Archive)
    {
        auto rar_host = std::dynamic_pointer_cast<UnRARHost>(Host());
        if(m_Entry->uuid < rar_host->LastItemUUID())
        {
            m_Archive->uid = m_Entry->uuid;
            if((uint64_t)m_TotalExtracted == m_Entry->unpacked_size)
            {
                rar_host->CommitSeekCache(move(m_Archive));
            }
            else
            {
                RARSetCallback(m_Archive->rar_handle, ProcessRARDummy, 0);
                if(RARProcessFile(m_Archive->rar_handle, RAR_TEST, NULL, NULL) == 0)
                {
                    rar_host->CommitSeekCache(move(m_Archive));
                }
            }
        }
        
        m_Archive.reset();
    }
    
    m_Entry = nullptr;
    
    if(m_UnpackSemaphore) {
        //dispatch_release(m_UnpackSemaphore);
        m_UnpackSemaphore = nullptr;
    }
    
    if(m_ConsumeSemaphore) {
        //dispatch_release(m_ConsumeSemaphore);
        m_ConsumeSemaphore = nullptr;
    }
    
    m_ExitUnpacking = false;

    return 0;
}

int File::ProcessRAR(unsigned int _msg, long _user_data, long _p1, long _p2)
{
    auto _this = (File *)_user_data;
    
	switch(_msg) {
		case UCM_CHANGEVOLUME:
			break;
		case UCM_PROCESSDATA:
        {
            dispatch_semaphore_wait(_this->m_UnpackSemaphore, DISPATCH_TIME_FOREVER);
            if(_this->m_ExitUnpacking)
                return -1;
            
            if(_this->m_UnpackBufferSize + _p2 > _this->m_UnpackBufferCapacity)
            {
                // grow buffer accordingly
                unsigned new_capacity = _this->m_UnpackBufferSize + (unsigned)_p2;
                std::unique_ptr<uint8_t[]> buf(new uint8_t[new_capacity]);
                memcpy(buf.get(),
                       _this->m_UnpackBuffer.get(),
                       _this->m_UnpackBufferSize);
                _this->m_UnpackBuffer.swap(buf);
                _this->m_UnpackBufferCapacity = new_capacity;
            }
            
            const void *unpacked_data = (void*)_p1;
            memcpy(_this->m_UnpackBuffer.get() + _this->m_UnpackBufferSize,
                   unpacked_data,
                   _p2
                   );
            _this->m_UnpackBufferSize += _p2;
            _this->m_TotalExtracted += _p2;
            
            dispatch_semaphore_signal(_this->m_ConsumeSemaphore);
            
			break;
        }
		case UCM_NEEDPASSWORD:
			break;
	}

	return 0;
}

int File::ProcessRARDummy(unsigned int _msg, long _user_data, long _p1, long _p2)
{
    return 0;
}

ssize_t File::Read(void *_buf, const size_t _size)
{
    if(!m_Archive)
        return SetLastError(VFSError::InvalidCall);
    if(Eof())
        return 0;
  
    if(m_UnpackBufferSize == 0)
    {
        // if we don't have any data unpacked - ask for it
        if( m_ExtractionRunning == false )
            return SetLastError(VFSArchiveUnRARErrorToVFSError(m_RarError));
        
        dispatch_semaphore_signal(m_UnpackSemaphore);
        dispatch_semaphore_wait(m_ConsumeSemaphore, DISPATCH_TIME_FOREVER);
    }
        
    // just give unpacked data away, don't unpack any more now
    ssize_t sz = std::min(ssize_t(_size), ssize_t(m_UnpackBufferSize));
    assert(sz + m_Position <= (long)m_Entry->unpacked_size);
        
    memcpy(_buf,
           m_UnpackBuffer.get(),
           sz);
    memmove(m_UnpackBuffer.get(),
            m_UnpackBuffer.get() + sz,
            m_UnpackBufferSize - sz);
    m_UnpackBufferSize -= sz;
    m_Position += sz;
    
    assert( sz <= (long)_size );
    return sz;
}

VFSFile::ReadParadigm File::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

ssize_t File::Pos() const
{
    if(!m_Archive)
        return SetLastError(VFSError::InvalidCall);
    return m_Position;
}

ssize_t File::Size() const
{
    if(!m_Archive)
        return SetLastError(VFSError::InvalidCall);
    return m_Entry->unpacked_size;
}

bool File::Eof() const
{
    if(!m_Archive)
        return true;
    return m_Position >= (ssize_t)m_Entry->unpacked_size;
}

}
