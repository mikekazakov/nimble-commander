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

bool FileSearch::Go(string _from_path,
                    shared_ptr<VFSHost> _in_host,
                    int _options,
                    FoundCallBack _found_callback,
                    FinishCallBack _finish_callback)
{
    if(IsRunning())
        return false;
    
    assert(m_Callback == nil);
    
    m_Callback = _found_callback;
    m_FinishCallback = _finish_callback;
    m_SearchOptions = _options;
    
    m_Queue->Run(^{
        AsyncProcPrologue(_from_path, _in_host);
    });
    
    return true;
}

void FileSearch::Stop()
{
    m_Queue->Stop();
}

void FileSearch::Wait()
{
    m_Queue->Wait();
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
        if(m_Queue->IsStopped())
            break;
        
        string path = m_DirsFIFO.front();
        m_DirsFIFO.pop_front();
        
        _in_host->IterateDirectoryListing(path.c_str(),
                                      ^(const VFSDirEnt &_dirent)
                                      {
                                          string full_path = path;
                                          if(full_path.back() != '/') full_path += '/';
                                          full_path += _dirent.name;
                                          
                                          ProcessDirent(full_path.c_str(),
                                                        path.c_str(),
                                                        _dirent,
                                                        _in_host);
                                          
                                          return true;
                                      });
    }
}

void FileSearch::ProcessDirent(const char* _full_path,
                               const char* _dir_path,
                               const VFSDirEnt &_dirent,
                               VFSHost *_in_host
                               )
{
//    NSLog(@"%s", _full_path);
    bool failed_filtering = false;
    
    // Filter by filename
    if(failed_filtering == false &&
       m_FilterNameMask &&
       !FilterByFilename(_dirent.name)
       )
        failed_filtering = true;
    
    // Filter by file content
    if(failed_filtering == false && m_FilterContent)
    {
       if(_dirent.type != VFSDirEnt::Reg || !FilterByContent(_full_path, _in_host) )
           failed_filtering = true;
    }
    
    if(failed_filtering == false) {
        ProcessValidEntry(_full_path, _dir_path, _dirent, _in_host);
    }
    
    if(m_SearchOptions & Options::GoIntoSubDirs)
    {
        if(_dirent.type == VFSDirEnt::Dir)
        {
            m_DirsFIFO.emplace_back(_full_path);
        }
    }
        
    
}

bool FileSearch::FilterByContent(const char* _full_path, VFSHost *_in_host)
{
    shared_ptr<VFSFile> file;
    if(_in_host->CreateFile(_full_path, &file, 0) != 0)
        return false;
    
    if(file->Open(VFSFile::OF_Read) != 0)
        return false;
    
    FileWindow fw;
    if(fw.OpenFile(file) != 0 )
        return false;
    
    SearchInFile sif(&fw);
    sif.ToggleTextSearch((CFStringRef)CFBridgingRetain(m_FilterContent->text),
                         m_FilterContent->encoding);
    
    auto result = sif.Search(nullptr, nullptr, nil);
    
    fw.CloseFile();

    return result == SearchInFile::Result::Found;
}

bool FileSearch::FilterByFilename(const char* _filename)
{
    NSString *filename = [NSString stringWithUTF8StringNoCopy:_filename];
    if(filename == nil ||
       m_FilterNameMask->MatchName(filename) == false)
        return false;
    
    return true;
}

bool FileSearch::ProcessValidEntry(const char* _full_path,
                       const char* _dir_path,
                       const VFSDirEnt &_dirent,
                       VFSHost *_in_host)
{
    if(m_Callback)
        return m_Callback(_dirent.name, _dir_path);
    return true;
}

bool FileSearch::IsRunning() const
{
    return m_Queue->Empty() == false;
}
