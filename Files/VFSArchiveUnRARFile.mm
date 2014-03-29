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
    assert(m_ExtractionRunning == false);
}

int VFSArchiveUnRARFile::Open(int _open_flags, bool (^_cancel_checker)())
{
    if( strlen(RelativePath()) < 2 || RelativePath()[0] != '/' )
        return SetLastError(VFSError::NotFound);
    
    if(_open_flags & VFSFile::OF_Write)
        return SetLastError(VFSError::NotSupported); // UnRAR is Read-Only
    
    auto rar_host = dynamic_pointer_cast<VFSArchiveUnRARHost>(Host());
    auto entry = rar_host->FindEntry(RelativePath());
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
             NSLog(@"RARProcessFile returned %d", m_RarError);

         m_ExtractionRunning = false;
         dispatch_semaphore_signal(m_FinishUnpackSemaphore);
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
    
    assert(m_ExtractionRunning == false);
    
    if(m_Archive)
    {
        auto rar_host = dynamic_pointer_cast<VFSArchiveUnRARHost>(Host());
        if(m_Entry->uuid < rar_host->LastItemUUID())
        {
            m_Archive->uid = m_Entry->uuid;
            if(m_TotalExtracted == m_Entry->unpacked_size)
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
                // grow buffer accordingly
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
            _this->m_TotalExtracted += _p2;
            
            dispatch_semaphore_signal(_this->m_ConsumeSemaphore);
            
			break;
        }
		case UCM_NEEDPASSWORD:
			break;
	}

	return 0;
}

int VFSArchiveUnRARFile::ProcessRARDummy(unsigned int _msg, long _user_data, long _p1, long _p2)
{
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
        if( m_ExtractionRunning == false )
            return SetLastError(VFSArchiveUnRARErrorToVFSError(m_RarError));
        
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
