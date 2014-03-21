//
//  FileSearch.cpp
//  Files
//
//  Created by Michael G. Kazakov on 11.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "FileSearch.h"
#include "FileWindow.h"
#include "SearchInFile.h"
#include "Common.h"

FileSearch::FileSearch():
    m_FilterName(nullptr),
    m_Queue(SerialQueueT::Make())
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
    
    if(!m_FilterName &&
       !m_FilterContent &&
       !m_FilterSize )
        return false; // need at least one filter to be set
    
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
                                          if(m_Queue->IsStopped())
                                              return false;
                                          
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
    bool failed_filtering = false;
    
    // Filter by being a directory
    if(failed_filtering == false &&
       _dirent.type == VFSDirEnt::Dir &&
       (m_SearchOptions & Options::SearchForDirs) == 0 )
        failed_filtering = true;
    
    // Filter by filename
    if(failed_filtering == false &&
       m_FilterNameMask &&
       !FilterByFilename(_dirent.name)
       )
        failed_filtering = true;
    
    // Filter by filesize
    if(failed_filtering == false && m_FilterSize) {
        if(_dirent.type == VFSDirEnt::Reg) {
            VFSStat st;
            if(_in_host->Stat(_full_path, st, 0, 0) == 0) {
                if(st.size < m_FilterSize->min ||
                   st.size > m_FilterSize->max )
                    failed_filtering = true;
            }
            else
                failed_filtering = true;
        }
        else
            failed_filtering = true;
    }
    
    // Filter by file content
    if(failed_filtering == false && m_FilterContent)
    {
       if(_dirent.type != VFSDirEnt::Reg || !FilterByContent(_full_path, _in_host) )
           failed_filtering = true;
    }
    
    if(failed_filtering == false)
        ProcessValidEntry(_full_path, _dir_path, _dirent, _in_host);
    
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
    VFSFilePtr file;
    if(_in_host->CreateFile(_full_path, file, 0) != 0)
        return false;
    
    if(file->Open(VFSFile::OF_Read) != 0)
        return false;
    
    FileWindow fw;
    if(fw.OpenFile(file) != 0 )
        return false;
    
    SearchInFile sif(&fw);
    sif.ToggleTextSearch((__bridge CFStringRef)m_FilterContent->text, m_FilterContent->encoding);
    sif.SetSearchOptions((m_FilterContent->case_sensitive  ? SearchInFile::OptionCaseSensitive   : 0) |
                         (m_FilterContent->whole_phrase    ? SearchInFile::OptionFindWholePhrase : 0) );
    
    auto result = sif.Search(nullptr,
                             nullptr,
                             ^bool{
                                 return m_Queue->IsStopped();
                             }
                             );
    
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

void FileSearch::ProcessValidEntry(const char* _full_path,
                       const char* _dir_path,
                       const VFSDirEnt &_dirent,
                       VFSHost *_in_host)
{
    if(m_Callback)
        m_Callback(_dirent.name, _dir_path);
}

bool FileSearch::IsRunning() const
{
    return m_Queue->Empty() == false;
}

void FileSearch::SetFilterSize(FilterSize *_filter)
{
    if(_filter == nullptr)
        m_FilterSize.reset();
    else
        m_FilterSize.reset( new FilterSize(*_filter));
}