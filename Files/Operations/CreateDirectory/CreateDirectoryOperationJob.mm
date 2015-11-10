//
//  CreateDirectoryOperationJob.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "CreateDirectoryOperationJob.h"
#include <string.h>
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "../../RoutedIO.h"
#include "../../Common.h"

void CreateDirectoryOperationJob::Init(const char *_path, const char *_root_path, CreateDirectoryOperation *_operation)
{
    strcpy(m_Path, _path);
    strcpy(m_RootPath, _root_path);
    m_Operation = _operation;
    
    if(_path[0] == '/')
    {
        // assume that _path is a full path
        strcpy(m_Name, _path);
    }
    else
    {
        // assume that _path is local path, need to combine it with path from _root_path
        strcpy(m_Name, _root_path); // assume that _root_path is a full path and is not corrupted
        if( m_Name[strlen(m_Name)-1] != '/' ) strcat(m_Name, "/");
        strcat(m_Name, _path);
    }
}

void CreateDirectoryOperationJob::Do()
{
    auto &io = RoutedIO::Default;
    
    // TODO: directory access mode!!!

    const int maxdepth = 128; // 128 directories depth max
    struct stat stat_buffer;
    short slashpos[maxdepth];
    short absentpos[maxdepth];
    int ndirs = 0, nabsent = 0, pathlen = (int)strlen(m_Name);
    
    for(int i = pathlen-1; i > 0; --i )
        if(m_Name[i] == '/')
            slashpos[ndirs++] = i;
    
    // find absent directories in full path
    for(int i = 0; i < ndirs; ++i)
    {
        m_Name[ slashpos[i] ] = 0;
        if(io.stat(m_Name, &stat_buffer) == -1)
            absentpos[nabsent++] = i;
        m_Name[ slashpos[i] ] = '/';
    }
    
    m_Stats.StartTimeTracking();
    m_Stats.SetMaxValue(nabsent + 1);
    
    // mkdir absent directories prior to ending dir
    for(int i = nabsent-1; i >= 0; --i)
    {
        m_Name[slashpos[absentpos[i]]] = 0;
    domkdir1:
        if(io.mkdir(m_Name, 0777) == -1)
        {
            int result = [[m_Operation dialogOnDirCreationFailed:ErrnoToNSError() forDir:m_Name] WaitForResult];
            if (result == OperationDialogResult::Retry)
                goto domkdir1;
            if (result == OperationDialogResult::Stop)
            {
                SetStopped();
                return;
            }
        }
        m_Name[ slashpos[i] ] = '/';
        m_Stats.AddValue(1);
    }
    
domkdir2:
    if(io.mkdir(m_Name, 0755) == -1)
    {
        int result = [[m_Operation dialogOnDirCreationFailed:ErrnoToNSError() forDir:m_Name] WaitForResult];
        if (result == OperationDialogResult::Retry)
            goto domkdir2;
        if (result == OperationDialogResult::Stop)
        {
            SetStopped();
            return;
        }
    }

    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
}

