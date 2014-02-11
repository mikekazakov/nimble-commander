//
//  FileSearch.cpp
//  Files
//
//  Created by Michael G. Kazakov on 11.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <dirent.h>
#include "FileSearch.h"
#include "FileWindow.h"
#include "SearchInFile.h"
#include "Common.h"

FileSearch::FileSearch():
    m_FilterName(nullptr),
    m_Queue(make_shared<SerialQueueT>())
{
    m_Queue->OnDry(^{
        auto tmp = m_FinishCallback;
        m_FinishCallback = nil;
        m_Callback = nil;
        m_SearchOptions = 0;
        
        if(tmp)
            tmp();
    });
}

void FileSearch::SetFilterName(FilterName *_filter)
{
    if(_filter == nullptr)
    {
        m_FilterName.reset();
        m_FilterNameMask.reset();
    }
    else
    {
        m_FilterName.reset(new FilterName(*_filter));
        m_FilterNameMask.reset( new FileMask(m_FilterName->mask) );
    }
}

void FileSearch::SetFilterContent(FilterContent *_filter)
{
    if(_filter == nullptr)
        m_FilterContent.reset();
    else
        m_FilterContent.reset( new FilterContent(*_filter));
}

void FileSearch::Go(string _from_path,
                    shared_ptr<VFSHost> _in_host,
                    int _options,
                    FoundCallBack _found_callback,
                    FinishCallBack _finish_callback)
{
    assert(m_Callback == nil);
    
    m_Callback = _found_callback;
    m_FinishCallback = _finish_callback;
    m_SearchOptions = _options;
    
    m_Queue->Run(^{
        AsyncProcPrologue(_from_path, _in_host);
    });
}

void FileSearch::AsyncProcPrologue(string _from_path, shared_ptr<VFSHost> _in_host)
{
    AsyncProc(_from_path.c_str(), _in_host.get());
}

void FileSearch::AsyncProc(const char *_from_path, VFSHost *_in_host)
{
    m_DirsFIFO.emplace_front(_from_path);
    
    while(!m_DirsFIFO.empty())
    {
        string path = m_DirsFIFO.front();
        m_DirsFIFO.pop_front();
        
        _in_host->IterateDirectoryListing(path.c_str(),
                                      ^(struct dirent &_dirent)
                                      {
                                          string full_path = path;
                                          if(full_path.back() != '/') full_path += '/';
                                          full_path += _dirent.d_name;
                                          
                                          ProcessDirent(full_path.c_str(),
                                                        _from_path,
                                                        _dirent,
                                                        _in_host);
                                          
                                          return true;
                                      });
    }
}

void FileSearch::ProcessDirent(const char* _full_path,
                               const char* _dir_path,
                               struct dirent &_dirent,
                               VFSHost *_in_host
                               )
{
//    NSLog(@"%s", _full_path);
    bool failed_filtering = false;
    
    if(failed_filtering == false &&
       m_FilterNameMask) {
        NSString *filename = [NSString stringWithUTF8StringNoCopy:_dirent.d_name];
        if(filename == nil ||
           m_FilterNameMask->MatchName(filename) == false)
            failed_filtering = true;
    }
    
    if(failed_filtering == false &&
       _dirent.d_type == DT_REG  &&
       m_FilterContent) while(1) {
        shared_ptr<VFSFile> file;
        if(_in_host->CreateFile(_full_path, &file, 0) != 0) {
            failed_filtering = true;
            break;
        }
        
        if(file->Open(VFSFile::OF_Read) != 0) {
            failed_filtering = true;
            break;
        }
        
        FileWindow fw;
        if(fw.OpenFile(file) != 0 ) {
            failed_filtering = true;
            break;
        }
        
        SearchInFile sif(&fw);
        sif.ToggleTextSearch((CFStringRef)CFBridgingRetain(m_FilterContent->text),
                             m_FilterContent->encoding);
        
        auto result = sif.Search(nullptr, nullptr, nil);
        if(result != SearchInFile::Result::Found)
            failed_filtering = true;
        
        fw.CloseFile();

        break;
    }
    
    
    if(failed_filtering == false) {
        NSLog(@"%s", _full_path);
    }
    
    if(m_SearchOptions & Options::GoIntoSubDirs)
    {
        if(_dirent.d_type == DT_DIR)
        {
            m_DirsFIFO.emplace_back(_full_path);
        }
    }
        
    
}
