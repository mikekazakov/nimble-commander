//
//  FileDeletionOperationJob.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionOperationJob.h"
#import "NativeFSManager.h"
#import "OperationDialogAlert.h"
#import "rdrand.h"
#import "Common.h"
#import "RoutedIO.h"

static void Randomize(unsigned char *_data, unsigned _size)
{
    // try to use Intel's rdrand instruction directly, don't waste CPU time on manual rand calculation
    // Ivy Bridge(2012) and later
    int r = rdrand_get_bytes(_size, _data);
    if( r != RDRAND_SUCCESS)
    {
        // fallback mode - call traditional sluggish random
        random_device rd;
        mt19937 mt(rd());
        uniform_int_distribution<unsigned char> dist(0, 255);

        for(unsigned i = 0; i < _size; ++i)
            _data[i] = dist(mt);
    }
}

static inline bool CanBeExternalEA(const char *_short_filename)
{
    return  _short_filename[0] == '.' &&
            _short_filename[1] == '_' &&
            _short_filename[2] != 0;
}

static inline bool EAHasMainFile(const char *_full_ea_path)
{
    char tmp[MAXPATHLEN];
    strcpy(tmp, _full_ea_path);
    
    char *last_dst = strrchr(tmp, '/');
    const char *last_src = strrchr(_full_ea_path, '/'); // suboptimal
    
    strcpy(last_dst + 1, last_src + 3);
           
    struct stat st;
    return lstat(tmp, &st) == 0;
}

void FileDeletionOperationJob::Init(vector<string>&& _files, FileDeletionOperationType _type, const string& _dir, FileDeletionOperation *_op)
{
    m_RequestedFiles = move(_files);
    m_Type = _type;
    m_RootPath = _dir;
    if(m_RootPath.back() != '/') m_RootPath += '/';
    m_Operation = _op;
}

void FileDeletionOperationJob::Do()
{
    auto volume = NativeFSManager::Instance().VolumeFromPath(m_RootPath);
    if(volume)
        m_RootHasExternalEAs = volume->interfaces.extended_attr == false;    
    
    DoScan();

    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    char entryfilename[MAXPATHLEN], *entryfilename_var;
    strcpy(entryfilename, m_RootPath.c_str());
    entryfilename_var = &entryfilename[0] + strlen(entryfilename);
    
    m_Stats.StartTimeTracking();
    m_Stats.SetMaxValue(m_ItemsToDelete.size());
    
    for(auto &i: m_ItemsToDelete)
    {
        if(CheckPauseOrStop()) { SetStopped(); return; }
        
        m_Stats.SetCurrentItem(i.c_str());
        
        i.str_with_pref(entryfilename_var);
        
        DoFile(entryfilename, i.c_str()[i.size() - 1] == '/');
    
        m_Stats.AddValue(1);
    }
    
    m_Stats.SetCurrentItem(0);
    
    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
}

void FileDeletionOperationJob::DoScan()
{
    auto &io = RoutedIO::InterfaceForAccess(m_RootPath.c_str(), R_OK);
    for(auto &i: m_RequestedFiles)
    {
        if (CheckPauseOrStop()) return;
        char fn[MAXPATHLEN];
        strcpy(fn, m_RootPath.c_str());
        strcat(fn, i.c_str()); // TODO: optimize me
        
        struct stat st;
        if(io.lstat(fn, &st) == 0)
        {
            if((st.st_mode&S_IFMT) == S_IFREG)
            {
                // trivial case
                bool skip = false;
                if( m_RootHasExternalEAs && CanBeExternalEA(i.c_str()) && EAHasMainFile(fn) )
                    skip = true;
                
                if(!skip)
                    m_ItemsToDelete.push_back(i.c_str(), (unsigned)i.size(), nullptr);
            }
            else if((st.st_mode&S_IFMT) == S_IFLNK)
            {
                m_ItemsToDelete.push_back(i.c_str(), (unsigned)i.size(), nullptr);
            }
            else if((st.st_mode&S_IFMT) == S_IFDIR)
            {
                char tmp[MAXPATHLEN]; // i.str() + '/'
                memcpy(tmp, i.c_str(), i.size());
                tmp[i.size()] = '/';
                tmp[i.size()+1] = 0;
                
                // add new dir in our tree structure
                m_Directories.push_back(tmp, nullptr);
                
                auto dirnode = &m_Directories.back();
                
                // for moving to trash we need just to delete the topmost directories to preserve structure
                if(m_Type != FileDeletionOperationType::MoveToTrash)
                {
                    // add all items in directory
                    DoScanDir(fn, dirnode);
                }

                // add directory itself at the end, since we need it to be deleted last of all
                m_ItemsToDelete.push_back(tmp, (unsigned)i.size()+1, nullptr);
            }
        }
    }
}

void FileDeletionOperationJob::DoScanDir(const char *_full_path, const chained_strings::node *_prefix)
{
    auto &io = RoutedIO::InterfaceForAccess(_full_path, R_OK);
    
    char fn[MAXPATHLEN], *fnvar; // fnvar - is a variable part for every file in directory
    strcpy(fn, _full_path);
    strcat(fn, "/");
    fnvar = &fn[0] + strlen(fn);
    
retry_opendir:
    DIR *dirp = io.opendir(_full_path);
    if( dirp != 0)
    {
        dirent *entp;
        while((entp = io.readdir(dirp)) != NULL)
        {
            if( (entp->d_namlen == 1 && entp->d_name[0] ==  '.' ) ||
               (entp->d_namlen == 2 && entp->d_name[0] ==  '.' && entp->d_name[1] ==  '.') )
                continue;

            // replace variable part with current item, so fn is RootPath/item_file_name now
            memcpy(fnvar, entp->d_name, entp->d_namlen+1);
            
            if( entp->d_type == DT_REG )
            {
                bool skip = false;
                if( m_RootHasExternalEAs && CanBeExternalEA(entp->d_name) && EAHasMainFile(fn) )
                    skip = true;
                
                if(!skip)
                    m_ItemsToDelete.push_back(entp->d_name, entp->d_namlen, _prefix);
            }
            else if( entp->d_type == DT_LNK )
            {
                m_ItemsToDelete.push_back(entp->d_name, entp->d_namlen, _prefix);
            }
            else if( entp->d_type == DT_DIR )
            {
                char tmp[MAXPATHLEN];
                memcpy(tmp, entp->d_name, entp->d_namlen);
                tmp[entp->d_namlen] = '/';
                tmp[entp->d_namlen+1] = 0;
                // add new dir in our tree structure
                m_Directories.push_back(tmp, entp->d_namlen+1, _prefix);
                auto dirnode = &m_Directories.back();
                
                // add all items in directory
                DoScanDir(fn, dirnode);
                
                // add directory itself at the end, since we need it to be deleted last of all
                m_ItemsToDelete.push_back(tmp, entp->d_namlen+1, _prefix);
            }
            
        }
        io.closedir(dirp);
    }
    else if (!m_SkipAll) // if (dirp != 0)
    {
        int result = [[m_Operation DialogOnOpendirError:errno ForDir:_full_path] WaitForResult];
        if (result == OperationDialogResult::Retry) goto retry_opendir;
        else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
        else if (result == OperationDialogResult::Stop) RequestStop();
    }
}

void FileDeletionOperationJob::DoFile(const char *_full_path, bool _is_dir)
{
    if(m_Type == FileDeletionOperationType::Delete)
    {
        DoDelete(_full_path, _is_dir);
    }
    else if(m_Type == FileDeletionOperationType::MoveToTrash)
    {
        DoMoveToTrash(_full_path, _is_dir);
    }
    else if(m_Type == FileDeletionOperationType::SecureDelete)
    {
        DoSecureDelete(_full_path, _is_dir);
    }
}

bool FileDeletionOperationJob::DoDelete(const char *_full_path, bool _is_dir)
{
    auto &io = RoutedIO::Default;
    int ret = -1;
    // delete. just delete.
    if( !_is_dir )
    {
    retry_unlink:
        ret = io.unlink(_full_path);
        if( ret != 0 && !m_SkipAll )
        {
            int result = [[m_Operation DialogOnUnlinkError:errno ForPath:_full_path] WaitForResult];
            if (result == OperationDialogResult::Retry) goto retry_unlink;
            else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
            else if (result == OperationDialogResult::Stop) RequestStop();
        }
    }
    else
    {
    retry_rmdir:
        ret = io.rmdir(_full_path);
        if( ret != 0 && !m_SkipAll )
        {
            int result = [[m_Operation DialogOnRmdirError:errno ForPath:_full_path] WaitForResult];
            if (result == OperationDialogResult::Retry) goto retry_rmdir;
            else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
            else if (result == OperationDialogResult::Stop) RequestStop();
        }
    }
    return ret == 0;
}

bool FileDeletionOperationJob::DoMoveToTrash(const char *_full_path, bool _is_dir)
{
    NSString *str  = [NSString stringWithUTF8String:_full_path];
    NSURL *path = [NSURL fileURLWithPath:str isDirectory:_is_dir];
    NSURL *newpath;
    NSError *error;
    // Available in OS X v10.8 and later
retry_delete:
    if(![[NSFileManager defaultManager] trashItemAtURL:path resultingItemURL:&newpath error:&error])
    {
        if (!m_SkipAll)
        {
            int result = [[m_Operation DialogOnTrashItemError:error ForPath:_full_path]
                          WaitForResult];
            if (result == OperationDialogResult::Retry) goto retry_delete;
            else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
            else if (result == OperationDialogResult::Stop) RequestStop();
            else if (result == FileDeletionOperationDR::DeletePermanently)
            {
                // User can choose to delete item permanently.
                return DoDelete(_full_path, _is_dir);
            }
        }
        return false;
    }
  
    return true;
}

bool FileDeletionOperationJob::DoSecureDelete(const char *_full_path, bool _is_dir)
{
    auto &io = RoutedIO::Default;
    if( !_is_dir )
    {
        // fill file content with random data
        unsigned char data[4096];
        const int passes=3;

        struct stat st;
        if( io.lstat(_full_path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFLNK)
        {
            // just unlink a symlink, do not try to fill it with trash -
            // it produces fancy "Too many levels of symbolic links" error
            unlink_symlink:
            if(io.unlink(_full_path) != 0)
            {
                if (!m_SkipAll)
                {
                    int result = [[m_Operation DialogOnUnlinkError:errno ForPath:_full_path]
                                  WaitForResult];
                    if (result == OperationDialogResult::Retry) goto unlink_symlink;
                    else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                    else if (result == OperationDialogResult::Stop) RequestStop();
                }
                return false;
            }
            return true;
        }
        
    retry_open:
        int fd = io.open(_full_path, O_WRONLY|O_EXLOCK|O_NOFOLLOW);
        if(fd != -1)
        {
            // TODO: error handlings!!!
            off_t size = lseek(fd, 0, SEEK_END);
            for(int pass=0; pass < passes; ++pass)
            {
                lseek(fd, 0, SEEK_SET);
                off_t written=0;
                while(written < size)
                {
                    Randomize(data, 4096);
                retry_write:
                    ssize_t wn = write(fd, data, size - written > 4096 ? 4096 : size - written);
                    if(wn >= 0)
                    {
                        written += wn;
                    }
                    else
                    {
                        if (!m_SkipAll)
                        {
                            int result = [[m_Operation DialogOnUnlinkError:errno
                                                                   ForPath:_full_path]
                                          WaitForResult];
                            if (result == OperationDialogResult::Retry) goto retry_write;
                            else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                            else if (result == OperationDialogResult::Stop)
                                RequestStop();
                        }
                        
                        // Break on skip, continue or abort.
                        break;
                    }
                }
            }
            close(fd);
            
        retry_unlink:
            // now delete it on file system level
            if(io.unlink(_full_path) != 0)
            {
                if (!m_SkipAll)
                {
                    int result = [[m_Operation DialogOnUnlinkError:errno ForPath:_full_path]
                                  WaitForResult];
                    if (result == OperationDialogResult::Retry) goto retry_unlink;
                    else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                    else if (result == OperationDialogResult::Stop) RequestStop();
                }
                return false;
            }
        }
        else
        {
            if (!m_SkipAll)
            {
                int result = [[m_Operation DialogOnUnlinkError:errno ForPath:_full_path]
                              WaitForResult];
                if (result == OperationDialogResult::Retry) goto retry_open;
                else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                else if (result == OperationDialogResult::Stop)
                    RequestStop();
            }
            return false;
        }
    }
    else
    {
    retry_rmdir:
        if(io.rmdir(_full_path) != 0 )
        {
            if (!m_SkipAll)
            {
                int result = [[m_Operation DialogOnRmdirError:errno ForPath:_full_path]
                              WaitForResult];
                if (result == OperationDialogResult::Retry) goto retry_rmdir;
                else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                else if (result == OperationDialogResult::Stop) RequestStop();
            }
            return false;
        }
    }
    return true;
}

