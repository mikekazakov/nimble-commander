//
//  FileSysAttrChangeOperationJob.mm
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
#include "../../vfs/vfs_native.h"
#include "../../RoutedIO.h"
#include "../../Common.h"
#include "FileSysAttrChangeOperation.h"
#include "FileSysAttrChangeOperationJob.h"

FileSysAttrChangeOperationJob::FileSysAttrChangeOperationJob():
    m_Operation(nil),
    m_SkipAllErrors(false)
{
}

void FileSysAttrChangeOperationJob::Init(FileSysAttrAlterCommand _command, FileSysAttrChangeOperation *_operation)
{
    if( !all_of(begin(*_command.items), end(*_command.items), [](auto &i){ return i.Host()->IsNativeFS();}) )
       throw invalid_argument("FileSysAttrChangeOperationJob::Init was called with elements of non-native host!");
    
    m_Command = move(_command);
    m_Operation = _operation;
}

void FileSysAttrChangeOperationJob::Do()
{

    if( m_Command.process_subdirs ) {
        DoScan();
        
    }
    else {
        // just use original files list
        for( auto &i:*m_Command.items ) {
            SourceItem it;
            it.item_name = i.Filename();
            it.base_dir_index = (unsigned)linear_find_or_insert(m_SourceItemsBaseDirectories, i.Directory());
            m_SourceItems.emplace_back( move(it) );
        }
        
        
//        struct SourceItem
//        {
//            // full path = m_SourceItemsBaseDirectories[base_dir_index] + ... + m_Items[m_Items[parent_index].parent_index].item_name +  m_Items[parent_index].item_name + item_name;
//            string      item_name;
//            int         parent_index;
//            unsigned    base_dir_index;
//            //        uint16_t    host_index;
//            //        uint16_t    mode;
//        };
        
        
    }
        
        
    
//    if(m_Command->process_subdirs)
//    {
//        ScanDirs();
//    }
//    else
//    {
//        // just use original files list
//        m_Files.swap(m_Command->files);
//    }
//    unsigned items_count = m_Files.size();
//    assert(items_count != 0);
//
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
//    char entryfilename[MAXPATHLEN], *entryfilename_var;
//    strcpy(entryfilename, m_Command->root_path.c_str());
//    entryfilename_var = &entryfilename[0] + strlen(entryfilename);
    
    m_Stats.StartTimeTracking();
    m_Stats.SetMaxValue(m_SourceItems.size());
    
    for(auto &i: m_SourceItems) {
        m_Stats.SetCurrentItem( i.item_name );
        
//        i.str_with_pref(entryfilename_var);
        auto path = ComposeFullPath(i);

        DoFile(path.c_str());
        if(CheckPauseOrStop()) { SetStopped(); return; }
        
        m_Stats.AddValue(1);
    }
    
    m_Stats.SetCurrentItem("");
    SetCompleted();
}

string FileSysAttrChangeOperationJob::ComposeFullPath( const SourceItem &_meta ) const
{
    array<int, 128> parents;
    int parents_num = 0;
    
    int parent = _meta.parent_index;
    while( parent >= 0 ) {
        parents[parents_num++] = parent;
        parent = m_SourceItems[parent].parent_index;
    }
    
    string path = m_SourceItemsBaseDirectories.at(_meta.base_dir_index);
    for( int i = parents_num - 1; i >= 0; i-- )
        path += m_SourceItems[ parents[i] ].item_name;
    
    path += _meta.item_name;
    return path;
    
}

void FileSysAttrChangeOperationJob::DoScan()
{
    auto &io = RoutedIO::Default;
    
    auto add = [&](unsigned _base_dir, int _parent_ind, string _item_name, struct stat &_st)->int{
        SourceItem it;
        it.item_name = S_ISDIR(_st.st_mode) ? EnsureTrailingSlash( move(_item_name) ) : move(_item_name);
        it.base_dir_index = _base_dir;
        it.parent_index = _parent_ind;
        m_SourceItems.emplace_back( move(it) );
        return int(m_SourceItems.size() - 1);
    };
    
    for( auto &i: *m_Command.items ) {
        if(CheckPauseOrStop())
            return;
        
        auto base_dir_indx = (unsigned)linear_find_or_insert(m_SourceItemsBaseDirectories, i.Directory());
        function<void(int _parent_ind, const string &_full_relative_path, const string &_item_name)> // need function holder for recursion to work
        scan_item = [this, &add, &io, base_dir_indx, &scan_item] (int _parent_ind,
                                                       const string &_full_relative_path,
                                                       const string &_item_name
                                                       ) {
            // compose a full path for current entry
            string path = m_SourceItemsBaseDirectories[base_dir_indx] + _full_relative_path;

            // gather stat() information regarding current entry
            struct stat st;
            if( io.stat(path.c_str(), &st) == 0 ) {
                int current_index = -1;
                if( S_ISREG(st.st_mode) ) {
                    current_index = add(base_dir_indx, _parent_ind, _item_name, st);
                }
                else if( S_ISDIR(st.st_mode) ) {
                    current_index = add(base_dir_indx, _parent_ind, _item_name, st);
                    
                    vector<string> dir_ents;
                    VFSNativeHost::SharedHost()->IterateDirectoryListing(path.c_str(), [&](auto &_) { dir_ents.emplace_back(_.name); return true; });
                        
                    for( auto &entry: dir_ents ) {
                        if(CheckPauseOrStop())
                            return;
                        // go into recursion
                        scan_item(current_index,
                                  _full_relative_path + '/' + entry,
                                  entry);
                    }
                }
            }
        };
        scan_item(-1,
                  i.Filename(),
                  i.Filename()
                  );
    }
    
    if(CheckPauseOrStop())
        return;
}

//void FileSysAttrChangeOperationJob::ScanDirs()
//{
//    auto &io = RoutedIO::Default;
//    
//    // iterates on original files list, find if entry is a dir, and if so then process it recursively
//    for(auto &i: m_Command->files)
//    {
//        char fn[MAXPATHLEN];
//        strcpy(fn, m_Command->root_path.c_str());
//        strcat(fn, i.c_str());
//        
//        struct stat st;
//        if(io.stat(fn, &st) == 0)
//        {
//            if((st.st_mode&S_IFMT) == S_IFREG)
//            {
//                // trivial case
//                m_Files.push_back(i.c_str(), i.size(), nullptr);
//            }
//            else if((st.st_mode&S_IFMT) == S_IFDIR)
//            {
//                char tmp[MAXPATHLEN];
//                strcpy(tmp, i.c_str());
//                strcat(tmp, "/");
//                m_Files.push_back(tmp, nullptr);
//                auto dirnode = &m_Files.back();
//                ScanDir(fn, dirnode);
//                if (CheckPauseOrStop()) return;
//            }
//        }
//    }
//}

//void FileSysAttrChangeOperationJob::ScanDir(const char *_full_path, const chained_strings::node *_prefix)
//{
//    if(CheckPauseOrStop()) return;
//    
//    auto &io = RoutedIO::InterfaceForAccess(_full_path, R_OK);
//    
//    char fn[MAXPATHLEN];
//retry_opendir:
//    DIR *dirp = io.opendir(_full_path);
//    if( dirp == 0)
//    {
//        if (!m_SkipAllErrors)
//        {
//            // Handle error.
//            int result = [[m_Operation DialogOnOpendirError:errno ForDir:_full_path]
//                          WaitForResult];
//            if (result == OperationDialogResult::Stop)
//            {
//                RequestStop();
//                return;
//            }
//            if (result == OperationDialogResult::SkipAll)
//                m_SkipAllErrors = true;
//            if (result == OperationDialogResult::Retry)
//                goto retry_opendir;
//        }
//    }
//    else
//    {
//        dirent *entp;
//        while((entp = io.readdir(dirp)) != NULL)
//        {
//            if( (entp->d_namlen == 1 && entp->d_name[0] ==  '.' ) ||
//                (entp->d_namlen == 2 && entp->d_name[0] ==  '.' && entp->d_name[1] ==  '.') )
//                    continue;
//
//            sprintf(fn, "%s/%s", _full_path, entp->d_name); // TODO: optimize me
//            
//            struct stat st;
//retry_stat:
//            if(io.stat(fn, &st) != 0)
//            {
//                if (!m_SkipAllErrors)
//                {
//                    // Handle error.
//                    int result = [[m_Operation DialogOnStatError:errno ForPath:_full_path]
//                                  WaitForResult];
//                    if (result == OperationDialogResult::Stop)
//                    {
//                        RequestStop();
//                        break;
//                    }
//                    if (result == OperationDialogResult::SkipAll)
//                        m_SkipAllErrors = true;
//                    if (result == OperationDialogResult::Retry)
//                        goto retry_stat;
//                }
//            }
//            else
//            {
//                if((st.st_mode&S_IFMT) == S_IFREG)
//                {
//                    m_Files.push_back(entp->d_name, entp->d_namlen, _prefix);
//                }
//                else if((st.st_mode&S_IFMT) == S_IFDIR)
//                {
//                    char tmp[MAXPATHLEN];
//                    memcpy(tmp, entp->d_name, entp->d_namlen);
//                    tmp[entp->d_namlen] = '/';
//                    tmp[entp->d_namlen+1] = 0;
//                    m_Files.push_back(tmp, entp->d_namlen+1, _prefix);
//                    ScanDir(fn, &m_Files.back());
//                }
//            }
//        }        
//        io.closedir(dirp);
//    }
//}

void FileSysAttrChangeOperationJob::DoFile(const char *_full_path)
{
    auto &io = RoutedIO::Default;
    
    // TODO: statfs to see if attribute is meaningful
    // TODO: need an additional checkbox to work with symlinks.
    
    // stat current file. no stat - no change.
    struct stat st;
retry_stat:
    if(io.stat(_full_path, &st) != 0)
    {
        if (!m_SkipAllErrors)
        {
            // Handle error.
            int result = [[m_Operation DialogOnStatError:errno ForPath:_full_path]
                          WaitForResult];
            if (result == OperationDialogResult::Stop)
            {
                RequestStop();
                return;
            }
            if (result == OperationDialogResult::SkipAll)
                m_SkipAllErrors = true;
            if (result == OperationDialogResult::Retry)
                goto retry_stat;
        }
    }
    
    // process unix access modes
    mode_t newmode = st.st_mode;
#define DOACCESS(_f, _c)\
    if(m_Command.flags[FileSysAttrAlterCommand::_f] == true) newmode |= _c;\
    if(m_Command.flags[FileSysAttrAlterCommand::_f] == false) newmode &= ~_c;
    DOACCESS(fsf_unix_usr_r, S_IRUSR);
    DOACCESS(fsf_unix_usr_w, S_IWUSR);
    DOACCESS(fsf_unix_usr_x, S_IXUSR);
    DOACCESS(fsf_unix_grp_r, S_IRGRP);
    DOACCESS(fsf_unix_grp_w, S_IWGRP);
    DOACCESS(fsf_unix_grp_x, S_IXGRP);
    DOACCESS(fsf_unix_oth_r, S_IROTH);
    DOACCESS(fsf_unix_oth_w, S_IWOTH);
    DOACCESS(fsf_unix_oth_x, S_IXOTH);
    DOACCESS(fsf_unix_suid,  S_ISUID);
    DOACCESS(fsf_unix_sgid,  S_ISGID);
    DOACCESS(fsf_unix_sticky,S_ISVTX);
#undef DOACCESS
    if(newmode != st.st_mode)
    {
        
retry_chmod:
        int res = io.chmod(_full_path, newmode);
        if(res != 0 && !m_SkipAllErrors)
        {
            int result = [[m_Operation DialogOnChmodError:errno
                                                  ForFile:_full_path
                                                 WithMode:newmode] WaitForResult];
            
            if (result == OperationDialogResult::Stop)
            {
                RequestStop();
                return;
            }
            if (result == OperationDialogResult::SkipAll)
                m_SkipAllErrors = true;
            if (result == OperationDialogResult::Retry)
                goto retry_chmod;
        }
    }
    
    // process file flags
    uint32_t newflags = st.st_flags;
#define DOFLAGS(_f, _c)\
    if(m_Command.flags[FileSysAttrAlterCommand::_f] == true) newflags |= _c;\
    if(m_Command.flags[FileSysAttrAlterCommand::_f] == false) newflags &= ~_c;
    DOFLAGS(fsf_uf_nodump, UF_NODUMP);
    DOFLAGS(fsf_uf_immutable, UF_IMMUTABLE);
    DOFLAGS(fsf_uf_append, UF_APPEND);
    DOFLAGS(fsf_uf_opaque, UF_OPAQUE);
    DOFLAGS(fsf_uf_hidden, UF_HIDDEN);
    DOFLAGS(fsf_uf_tracked, UF_TRACKED);
    DOFLAGS(fsf_sf_archived, SF_ARCHIVED);
    DOFLAGS(fsf_sf_immutable, SF_IMMUTABLE);
    DOFLAGS(fsf_sf_append, SF_APPEND);
#undef DOFLAGS
    if(newflags != st.st_flags)
    {
        
retry_chflags:
        int res = io.chflags(_full_path, newflags);
        if(res != 0 && !m_SkipAllErrors)
        {
            int result = [[m_Operation DialogOnChflagsError:errno
                                                    ForFile:_full_path
                                                  WithFlags:newflags] WaitForResult];
            
            if (result == OperationDialogResult::Stop)
            {
                RequestStop();
                return;
            }
            if (result == OperationDialogResult::SkipAll)
                m_SkipAllErrors = true;
            if (result == OperationDialogResult::Retry)
                goto retry_chflags;
        }
    }
        
    // process file owner and file group
    uid_t newuid = st.st_uid;
    gid_t newgid = st.st_gid;
    if(m_Command.uid) newuid = *m_Command.uid;
    if(m_Command.gid) newgid = *m_Command.gid;
    if(newuid != st.st_uid || newgid != st.st_gid)
    {
retry_chown:
        int res = io.chown(_full_path, newuid, newgid);
        if(res != 0 && !m_SkipAllErrors)
        {
            int result = [[m_Operation DialogOnChownError:errno
                                                  ForFile:_full_path
                                                      Uid:newuid
                                                      Gid:newgid] WaitForResult];
            
            if (result == OperationDialogResult::Stop)
            {
                RequestStop();
                return;
            }
            if (result == OperationDialogResult::SkipAll)
                m_SkipAllErrors = true;
            if (result == OperationDialogResult::Retry)
                goto retry_chown;
        }
    }
    
    // process file times
    
#define HANDLE_FILETIME_RESULT(label) \
    if (res != 0 && !m_SkipAllErrors) { \
        int result = [[m_Operation DialogOnFileTimeError:errno \
                        ForFile:_full_path WithAttr:attr Time:time] WaitForResult]; \
        if (result == OperationDialogResult::Stop) { RequestStop(); return; } \
        else if (result == OperationDialogResult::SkipAll) m_SkipAllErrors = true; \
        else if (result == OperationDialogResult::Retry) goto label; \
    }
    
    if(m_Command.atime && *m_Command.atime != st.st_atimespec.tv_sec) {
        uint32_t attr = ATTR_CMN_ACCTIME;
        timespec time = {*m_Command.atime, 0}; // yep, no msec and nsec
retry_acctime:
        int res = io.chatime(_full_path, *m_Command.atime);
        HANDLE_FILETIME_RESULT(retry_acctime);
    }

    if(m_Command.mtime && *m_Command.mtime != st.st_mtimespec.tv_sec) {
        uint32_t attr = ATTR_CMN_MODTIME;
        timespec time = {*m_Command.mtime, 0}; // yep, no msec and nsec
retry_modtime:
        int res = io.chmtime(_full_path, *m_Command.mtime);
        HANDLE_FILETIME_RESULT(retry_modtime);
    }
    
    if(*m_Command.ctime && *m_Command.ctime != st.st_ctimespec.tv_sec) {
        uint32_t attr  = ATTR_CMN_CHGTIME;
        timespec time = {*m_Command.ctime, 0}; // yep, no msec and nsec
retry_chgtime:
        int res = io.chctime(_full_path, *m_Command.ctime);
        HANDLE_FILETIME_RESULT(retry_chgtime);
    }
    
    if(*m_Command.btime && m_Command.btime != st.st_birthtimespec.tv_sec) {
        uint32_t attr = ATTR_CMN_CRTIME;
        timespec time = {*m_Command.btime, 0}; // yep, no msec and nsec
retry_crtime:
        int res = io.chbtime(_full_path, *m_Command.btime);
        HANDLE_FILETIME_RESULT(retry_crtime);
    }
    
#undef HANDLE_FILETIME_ERROR
}