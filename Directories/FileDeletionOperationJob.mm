//
//  FileDeletionOperationJob.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileDeletionOperationJob.h"
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/time.h>
#include <sys/xattr.h>
#include <sys/attr.h>
#include <sys/vnode.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <unistd.h>

FileDeletionOperationJob::FileDeletionOperationJob():
    m_RequestedFiles(0),
    m_Type(FileDeletionOperationType::Invalid),
    m_ItemsCount(0),
    m_CurrentItemNumber(0)
{
    
}

FileDeletionOperationJob::~FileDeletionOperationJob()
{
    
}

void FileDeletionOperationJob::Init(FlexChainedStringsChunk *_files, FileDeletionOperationType _type, const char* _root)
{
    m_RequestedFiles = _files;
    m_Type = _type;
    strcpy(m_RootPath, _root);
}

void FileDeletionOperationJob::Do()
{
    DoScan();

    m_ItemsCount = m_ItemsToDelete->CountStringsWithDescendants();
    
    char entryfilename[MAXPATHLEN], *entryfilename_var;
    strcpy(entryfilename, m_RootPath);
    entryfilename_var = &entryfilename[0] + strlen(entryfilename);
    
    for(auto &i: *m_ItemsToDelete)
    {
        i.str_with_pref(entryfilename_var);
        
        DoFile(entryfilename, i.str()[i.len-1] == '/');
    
        SetProgress(float(m_CurrentItemNumber) / float(m_ItemsCount));
        m_CurrentItemNumber++;
    }
    
    SetCompleted();
}

void FileDeletionOperationJob::DoScan()
{
    m_Directories = m_DirectoriesLast = FlexChainedStringsChunk::Allocate();
    m_ItemsToDelete = m_ItemsToDeleteLast = FlexChainedStringsChunk::Allocate();
    
    for(auto &i: *m_RequestedFiles)
    {
        char fn[MAXPATHLEN];
        strcpy(fn, m_RootPath);
        strcat(fn, i.str()); // TODO: optimize me

        struct stat st;
        if(lstat(fn, &st) == 0)
        {
            if((st.st_mode&S_IFMT) == S_IFREG || (st.st_mode&S_IFMT) == S_IFLNK)
            {
                // trivial case
                m_ItemsToDeleteLast = m_ItemsToDeleteLast->AddString(i.str(), i.len, 0);
            }
            else if((st.st_mode&S_IFMT) == S_IFDIR)
            {
                char tmp[MAXPATHLEN]; // i.str() + '/'
                memcpy(tmp, i.str(), i.len);
                tmp[i.len] = '/';
                tmp[i.len+1] = 0;
                
                // add new dir in our tree structure
                m_DirectoriesLast = m_DirectoriesLast->AddString(tmp, 0); // optimize it to exclude strlen using
                const FlexChainedStringsChunk::node *dirnode = &m_DirectoriesLast->back();
                
                // for moving to trash we need just to delete the topmost directories to preserve structure
                if(m_Type != FileDeletionOperationType::MoveToTrash)
                {
                    // add all items in directory
                    DoScanDir(fn, dirnode);
                }

                // add directory itself at the end, since we need it to be deleted last of all
                m_ItemsToDeleteLast = m_ItemsToDeleteLast->AddString(tmp, i.len+1, 0);
            }
        }
    }
}

void FileDeletionOperationJob::DoScanDir(const char *_full_path, const FlexChainedStringsChunk::node *_prefix)
{
    char fn[MAXPATHLEN], *fnvar; // fnvar - is a variable part for every file in directory
    strcpy(fn, _full_path);
    strcat(fn, "/");
    fnvar = &fn[0] + strlen(fn);
    
    DIR *dirp = opendir(_full_path);
    if( dirp != 0)
    {
        dirent *entp;
        while((entp = readdir(dirp)) != NULL)
        {
            if( (entp->d_namlen == 1 && entp->d_name[0] ==  '.' ) ||
               (entp->d_namlen == 2 && entp->d_name[0] ==  '.' && entp->d_name[1] ==  '.') )
                continue;

            // replace variable part with current item, so fn is RootPath/item_file_name now
            memcpy(fnvar, entp->d_name, entp->d_namlen+1);
            
            struct stat st;
            if(lstat(fn, &st) == 0)
            {
                if((st.st_mode&S_IFMT) == S_IFREG || (st.st_mode&S_IFMT) == S_IFLNK)
                {
                    m_ItemsToDeleteLast = m_ItemsToDeleteLast->AddString(entp->d_name, entp->d_namlen, _prefix);
                }
                else if((st.st_mode&S_IFMT) == S_IFDIR)
                {
                    char tmp[MAXPATHLEN];
                    memcpy(tmp, entp->d_name, entp->d_namlen);
                    tmp[entp->d_namlen] = '/';
                    tmp[entp->d_namlen+1] = 0;
                    // add new dir in our tree structure
                    m_DirectoriesLast = m_DirectoriesLast->AddString(tmp, entp->d_namlen+1, _prefix);
                    const FlexChainedStringsChunk::node *dirnode = &m_DirectoriesLast->back();                    
                    
                    // add all items in directory
                    DoScanDir(fn, dirnode);

                    // add directory itself at the end, since we need it to be deleted last of all
                    m_ItemsToDeleteLast = m_ItemsToDeleteLast->AddString(tmp, entp->d_namlen+1, _prefix);
                }
            }
            else
            {
                // TODO: error handling
            }
        }
        closedir(dirp);
    }
    else
    {
        //TODO: error handling.
    }
}

void FileDeletionOperationJob::DoFile(const char *_full_path, bool _is_dir)
{
    if(m_Type == FileDeletionOperationType::Delete)
    {
        // delete. just delete.
        if( !_is_dir )
        {
            if(unlink(_full_path) != 0 )
            {
                // TODO: error handling
            }
        }
        else
        {
            if(rmdir(_full_path) != 0 )
            {
                // TODO: error handling
            }
        }
    }
    else if(m_Type == FileDeletionOperationType::MoveToTrash)
    {
        // Available in OS X v10.8 and later
        // This construction is VERY slow. Thanks, Apple!
        NSString *str = [[NSString alloc ]initWithBytesNoCopy:(void*)_full_path
                                               length:strlen(_full_path)
                                             encoding:NSUTF8StringEncoding
                                         freeWhenDone:NO];
        NSURL *path = [NSURL fileURLWithPath:str isDirectory:_is_dir];
        NSURL *newpath;
        NSError *error;
        if(![[NSFileManager defaultManager] trashItemAtURL:path resultingItemURL:&newpath error:&error])
        {
            // TODO: error handling
            // current volume may not support trash bin, in this case the should (?) fallback to classic deleting
        }
    }
    
}
