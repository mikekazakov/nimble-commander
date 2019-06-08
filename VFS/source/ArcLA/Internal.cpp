// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internal.h"

namespace nc::vfs::arc {

ssize_t Mediator::myread([[maybe_unused]] struct archive *a,
                         void *client_data,
                         const void **buff)
{
    Mediator *_this = (Mediator *)client_data;
    *buff = &_this->buf[0];
        
    ssize_t result = _this->file->Read(&_this->buf[0], bufsz);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;
}
    
off_t Mediator::myseek([[maybe_unused]] struct archive *a,
                       void *client_data,
                       off_t offset,
                       int whence)
{
    Mediator *_this = (Mediator *)client_data;
    off_t result = _this->file->Seek(offset, whence);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;
}

void Mediator::setup(struct archive *a)
{
    assert(file.get() != 0);
    assert(file->GetReadParadigm() >= VFSFile::ReadParadigm::Seek);
    archive_read_set_callback_data(a, this);
    archive_read_set_read_callback(a, myread);
    archive_read_set_seek_callback(a, myseek);
}

State::State(const VFSFilePtr &_file, struct archive *_arc):
    m_File(_file),
    m_Archive(_arc)
{
    assert(m_Archive);
    assert(m_File);
    assert(m_File->IsOpened());
    assert(m_File->GetReadParadigm() >= VFSFile::ReadParadigm::Seek);
    Setup();
}

State::~State()
{
    archive_read_free(m_Archive);
}

void State::Setup()
{
    archive_read_set_callback_data(m_Archive, this);
    archive_read_set_read_callback(m_Archive, myread);
    archive_read_set_seek_callback(m_Archive, myseek);
}

ssize_t State::myread([[maybe_unused]] struct archive *a, void *client_data, const void **buff)
{
    auto _this = (State *)client_data;
    *buff = &_this->m_Buf;
    
    ssize_t result = _this->m_File->Read(&_this->m_Buf[0], BufferSize);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;   
}

off_t State::myseek([[maybe_unused]] struct archive *a, void *client_data, off_t offset, int whence)
{
    auto _this = (State *)client_data;
    off_t result = _this->m_File->Seek(offset, whence);
    if(result < 0)
        return ARCHIVE_FATAL; // handle somehow
    return result;
}

void State::SetEntry(struct archive_entry *_e, uint32_t _uid)
{
    assert(_uid >= m_UID);
    assert(_e);
    m_Entry = _e;
    m_UID = _uid;
    m_Consumed = false;
}

int State::Open()
{
    return archive_read_open1(m_Archive);
}

int State::Errno()
{
    return archive_errno(m_Archive);
}

}
