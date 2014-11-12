//
//  VFSArchiveInternal.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "VFSArchiveInternal.h"

ssize_t VFSArchiveMediator::myread(struct archive *a, void *client_data, const void **buff)
{
    VFSArchiveMediator *_this = (VFSArchiveMediator *)client_data;
    *buff = &_this->buf[0];
        
    ssize_t result = _this->file->Read(&_this->buf[0], bufsz);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;
}
    
off_t VFSArchiveMediator::myseek(struct archive *a, void *client_data, off_t offset, int whence)
{
    VFSArchiveMediator *_this = (VFSArchiveMediator *)client_data;
    off_t result = _this->file->Seek(offset, whence);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;
}

void VFSArchiveMediator::setup(struct archive *a)
{
    assert(file.get() != 0);
    assert(file->GetReadParadigm() >= VFSFile::ReadParadigm::Seek);
    archive_read_set_callback_data(a, this);
    archive_read_set_read_callback(a, myread);
    archive_read_set_seek_callback(a, myseek);
}

VFSArchiveState::VFSArchiveState(const VFSFilePtr &_file, struct archive *_arc):
    m_File(_file),
    m_Archive(_arc)
{
    assert(m_Archive);
    assert(m_File);
    assert(m_File->IsOpened());
    assert(m_File->GetReadParadigm() >= VFSFile::ReadParadigm::Seek);
    Setup();
}

VFSArchiveState::~VFSArchiveState()
{
    archive_read_free(m_Archive);
}

void VFSArchiveState::Setup()
{
    archive_read_set_callback_data(m_Archive, this);
    archive_read_set_read_callback(m_Archive, myread);
    archive_read_set_seek_callback(m_Archive, myseek);
}

ssize_t VFSArchiveState::myread(struct archive *a, void *client_data, const void **buff)
{
    VFSArchiveState *_this = (VFSArchiveState *)client_data;
    *buff = &_this->m_Buf;
    
    ssize_t result = _this->m_File->Read(&_this->m_Buf[0], BufferSize);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;   
}

off_t VFSArchiveState::myseek(struct archive *a, void *client_data, off_t offset, int whence)
{
    VFSArchiveState *_this = (VFSArchiveState *)client_data;
    off_t result = _this->m_File->Seek(offset, whence);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;
}

void VFSArchiveState::SetEntry(struct archive_entry *_e, uint32_t _uid)
{
    assert(_uid >= m_UID);
    assert(_e);
    m_Entry = _e;
    m_UID = _uid;
    m_Consumed = false;
}

int VFSArchiveState::Open()
{
    return archive_read_open1(m_Archive);
}

int VFSArchiveState::Errno()
{
    return archive_errno(m_Archive);
}
