//
//  FileLinkOperationJob.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <RoutedIO/RoutedIO.h>
#include "../OperationDialogAlert.h"
#include "FileLinkOperationJob.h"

FileLinkOperationJob::FileLinkOperationJob()
{
}

FileLinkOperationJob::~FileLinkOperationJob()
{
}

void FileLinkOperationJob::Init(const char* _orig_file, const char *_link_file, Mode _mode, FileLinkOperation *_op)
{
    strcpy(m_File, _orig_file);
    strcpy(m_Link, _link_file);
    m_Mode = _mode;
    m_Op = _op;    
}

void FileLinkOperationJob::Do()
{
    if(m_Mode == Mode::CreateSymLink)
        DoNewSymLink();
    else if(m_Mode == Mode::AlterSymlink)
        DoAlterSymLink();
    else if(m_Mode == Mode::CreateHardLink)
        DoNewHardLink();
    
    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
}

void FileLinkOperationJob::DoNewSymLink()
{
dotry:
    int op_result = RoutedIO::Default.symlink(m_File, m_Link);

    if( op_result != 0 ) {
        NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        int dialog_result = [[m_Op DialogNewSymlinkError:err] WaitForResult];
        if( dialog_result == OperationDialogResult::Retry )
            goto dotry;
        else if( dialog_result == OperationDialogResult::Stop )
            RequestStop();
    }
}

void FileLinkOperationJob::DoAlterSymLink()
{
dounlink:
    int op_result = RoutedIO::Default.unlink(m_Link);
    
    if( op_result != 0 ) {
        NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        int result = [[m_Op DialogAlterSymlinkError:err] WaitForResult];
        if (result == OperationDialogResult::Retry)
            goto dounlink;
        else if (result == OperationDialogResult::Stop)
        {
            RequestStop();
            return;            
        }
    }
    
dosymlink:
    op_result = RoutedIO::Default.symlink(m_File, m_Link);
    if( op_result != 0 ){
        NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        int result = [[m_Op DialogAlterSymlinkError:err] WaitForResult];
        if (result == OperationDialogResult::Retry)
            goto dosymlink;
        else if (result == OperationDialogResult::Stop)
            RequestStop();
    }
}

void FileLinkOperationJob::DoNewHardLink()
{
dotry:
    int op_result = RoutedIO::Default.link(m_File, m_Link);
    
    if( op_result != 0 ) {
        NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        int result = [[m_Op DialogNewHardlinkError:err] WaitForResult];
        if (result == OperationDialogResult::Retry)
            goto dotry;
        else if (result == OperationDialogResult::Stop)
            RequestStop();
    }
}
