//
//  VFSArchiveUnRARFile.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSArchiveUnRARFile.h"
#include "VFSArchiveUnRARHost.h"
#include "VFSArchiveUnRARInternals.h"

VFSArchiveUnRARFile::VFSArchiveUnRARFile(const char* _relative_path, shared_ptr<VFSArchiveUnRARHost> _host):
    VFSFile(_relative_path, _host),
    m_UnpackThread(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)),
    m_UnpackBuffer(new uint8_t[m_UnpackBufferDefaultCapacity]),
    m_UnpackBufferCapacity(m_UnpackBufferDefaultCapacity)
{
}

VFSArchiveUnRARFile::~VFSArchiveUnRARFile()
{
    Close();
}

int VFSArchiveUnRARFile::Open(int _open_flags)
{
    if( strlen(RelativePath()) < 2 || RelativePath()[0] != '/' )
        return SetLastError(VFSError::NotFound);
    
    if(_open_flags & VFSFile::OF_Write)
        return SetLastError(VFSError::NotSupported); // UnRAR is Read-Only
    
    auto host = dynamic_pointer_cast<VFSArchiveUnRARHost>(Host());

    auto entry = host->FindEntry(RelativePath());
    if(entry == 0)
        return SetLastError(VFSError::NotFound);

    m_Entry = entry;
    m_Archive = host->SeekCache(entry->uuid);
    
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
    
    
    m_ConsumeSemaphore = dispatch_semaphore_create(0);
    m_FinishUnpackSemaphore = dispatch_semaphore_create(0);
    m_UnpackSemaphore = dispatch_semaphore_create(0);
    
    auto shared_this = static_pointer_cast<VFSArchiveUnRARFile>(shared_from_this());
    dispatch_async(m_UnpackThread, ^{
        // hold shared_this in this block.
        RARSetCallback(shared_this->m_Archive->rar_handle, ProcessRAR, (long)shared_this.get());
        RARProcessFile(shared_this->m_Archive->rar_handle, RAR_EXTRACT, NULL, NULL);
        dispatch_semaphore_signal(shared_this->m_FinishUnpackSemaphore);
    });
    
    return 0;
}

bool VFSArchiveUnRARFile::IsOpened() const
{
    return m_Archive.get() != nullptr;
}

int VFSArchiveUnRARFile::Close()
{
    m_ExitUnpacking = true;
    
    if(m_FinishUnpackSemaphore) {
        dispatch_semaphore_signal(m_UnpackSemaphore);
        dispatch_semaphore_wait(m_FinishUnpackSemaphore, DISPATCH_TIME_FOREVER);
        dispatch_release(m_FinishUnpackSemaphore);
        m_FinishUnpackSemaphore = 0;
    }
    
    m_Archive.reset(); // commit it back to host here
    
    m_Entry = nullptr;
    
    if(m_UnpackSemaphore) {
        dispatch_release(m_UnpackSemaphore);
        m_UnpackSemaphore = nullptr;
    }
    
    if(m_ConsumeSemaphore) {
        dispatch_release(m_ConsumeSemaphore);
        m_ConsumeSemaphore = nullptr;
    }
    
    m_ExitUnpacking = false;

    return 0;
}

int VFSArchiveUnRARFile::ProcessRAR(unsigned int _msg, long _user_data, long _p1, long _p2)
{
    VFSArchiveUnRARFile *_this = (VFSArchiveUnRARFile *)_user_data;
    
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
                // grow buffer
                unsigned new_capacity = _this->m_UnpackBufferSize + (unsigned)_p2;
                unique_ptr<uint8_t[]> buf(new uint8_t[new_capacity]);
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
            
            dispatch_semaphore_signal(_this->m_ConsumeSemaphore);
            
			break;
        }
		case UCM_NEEDPASSWORD:
			break;
	}

	return 0;
}

ssize_t VFSArchiveUnRARFile::Read(void *_buf, size_t _size)
{
    if(!m_Archive)
        return SetLastError(VFSError::InvalidCall);
    if(Eof())
        return 0;
  
    if(m_UnpackBufferSize == 0)
    {
        // if we don't have any data unpacked - ask for it
        dispatch_semaphore_signal(m_UnpackSemaphore);
        dispatch_semaphore_wait(m_ConsumeSemaphore, DISPATCH_TIME_FOREVER);
    }
        
    // just give unpacked data away, don't unpack any more now
    ssize_t sz = min(ssize_t(_size), ssize_t(m_UnpackBufferSize));
    assert(sz + m_Position <= m_Entry->unpacked_size);
        
    memcpy(_buf,
           m_UnpackBuffer.get(),
           sz);
    memmove(m_UnpackBuffer.get(),
            m_UnpackBuffer.get() + sz,
            m_UnpackBufferSize - sz);
    m_UnpackBufferSize -= sz;
    m_Position += sz;
    return sz;
}

VFSFile::ReadParadigm VFSArchiveUnRARFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

ssize_t VFSArchiveUnRARFile::Pos() const
{
    if(!m_Archive)
        return SetLastError(VFSError::InvalidCall);
    return m_Position;
}

ssize_t VFSArchiveUnRARFile::Size() const
{
    if(!m_Archive)
        return SetLastError(VFSError::InvalidCall);
    return m_Entry->unpacked_size;
}

bool VFSArchiveUnRARFile::Eof() const
{
    if(!m_Archive)
        return true;
    return m_Position >= m_Entry->unpacked_size;
}
