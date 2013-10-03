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
