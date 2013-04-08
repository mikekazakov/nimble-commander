//
//  FileSysAttrChangeOperationJob.mm
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileSysAttrChangeOperationJob.h"
#include "FlexChainedStringsChunk.h"
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

#import "FileSysAttrChangeOperation.h"

FileSysAttrChangeOperationJob::FileSysAttrChangeOperationJob():
    m_ItemsCount(0),
    m_CurrentItemNumber(0),
    m_State(StateInvalid),
    m_Operation(nil),
    m_SkipAllErrors(false)
{
}

FileSysAttrChangeOperationJob::~FileSysAttrChangeOperationJob()
{
    if(m_Files != m_Command->files)
        FlexChainedStringsChunk::FreeWithDescendants(&m_Files);
    FlexChainedStringsChunk::FreeWithDescendants(&m_Command->files);
    free(m_Command);
}

void FileSysAttrChangeOperationJob::Init(FileSysAttrAlterCommand *_command, FileSysAttrChangeOperation *_operation)
{
    m_Command = _command;
    m_Operation = _operation;
}

FileSysAttrChangeOperationJob::State FileSysAttrChangeOperationJob::StateDetail(unsigned &_it_no, unsigned &_it_tot) const
{
    _it_no = m_CurrentItemNumber;
    _it_tot = m_ItemsCount;
    return m_State;
}

void FileSysAttrChangeOperationJob::Do()
{
    if(m_Command->process_subdirs)
    {
        m_State = StateScanning;
        ScanDirs();
    }
    else
    {
        // just use original files list
        m_Files = m_Command->files;
    }
    m_ItemsCount = m_Files->CountStringsWithDescendants();
    assert(m_ItemsCount != 0);
    
    m_State = StateSetting;

    if(GetState() == StateStopped) return;
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    char entryfilename[MAXPATHLEN], *entryfilename_var;
    strcpy(entryfilename, m_Command->root_path);
    entryfilename_var = &entryfilename[0] + strlen(entryfilename);
    
    for(auto &i: *m_Files)
    {
        if(CheckPauseOrStop()) { SetStopped(); return; }
        
        i.str_with_pref(entryfilename_var);

        DoFile(entryfilename);
        if(GetState() == StateStopped) return;
        
        SetProgress(float(m_CurrentItemNumber) / float(m_ItemsCount));
        m_CurrentItemNumber++;
    }
    
    SetCompleted();
    m_State = StateInvalid;
}

void FileSysAttrChangeOperationJob::ScanDirs()
{
    // iterates on original files list, find if entry is a dir, and if so then process it recursively
    m_FilesLast = m_Files = FlexChainedStringsChunk::Allocate();

    for(auto &i: *m_Command->files)
    {
        char fn[MAXPATHLEN];
        strcpy(fn, m_Command->root_path);
        strcat(fn, i.str());
        
        struct stat st;
        if(stat(fn, &st) == 0)
        {
            if((st.st_mode&S_IFMT) == S_IFREG)
            {
                // trivial case
                m_FilesLast = m_FilesLast->AddString(i.str(), i.len, 0);
            }
            else if((st.st_mode&S_IFMT) == S_IFDIR)
            {
                char tmp[MAXPATHLEN];
                strcpy(tmp, i.str());
                strcat(tmp, "/");
                m_FilesLast = m_FilesLast->AddString(tmp, 0); // optimize it to exclude strlen using
                const FlexChainedStringsChunk::node *dirnode = &m_FilesLast->back();
                ScanDir(fn, dirnode);
            }
        }
    }
}

void FileSysAttrChangeOperationJob::ScanDir(const char *_full_path, const FlexChainedStringsChunk::node *_prefix)
{
    if(GetState() == StateStopped) return;    
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    char fn[MAXPATHLEN];    
    DIR *dirp = opendir(_full_path);
    if( dirp != 0)
    {
        dirent *entp;
        while((entp = readdir(dirp)) != NULL)
        {
            if( (entp->d_namlen == 1 && entp->d_name[0] ==  '.' ) ||
                (entp->d_namlen == 2 && entp->d_name[0] ==  '.' && entp->d_name[1] ==  '.') )
                    continue;

            sprintf(fn, "%s/%s", _full_path, entp->d_name); // TODO: optimize me
            
            struct stat st;
            if(stat(fn, &st) == 0)
            {
                if((st.st_mode&S_IFMT) == S_IFREG)
                {
                    m_FilesLast = m_FilesLast->AddString(entp->d_name, entp->d_namlen, _prefix);
                }
                else if((st.st_mode&S_IFMT) == S_IFDIR)
                {
                    char tmp[MAXPATHLEN];
                    memcpy(tmp, entp->d_name, entp->d_namlen);
                    tmp[entp->d_namlen] = '/';
                    tmp[entp->d_namlen+1] = 0;
                    m_FilesLast = m_FilesLast->AddString(tmp, entp->d_namlen+1, _prefix);
                    const FlexChainedStringsChunk::node *dirnode = &m_FilesLast->back();
                    ScanDir(fn, dirnode);
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
        //TODO: error handling. maybe rights issue?
    }
}

void FileSysAttrChangeOperationJob::DoFile(const char *_full_path)
{
    // TODO: super-user rights asking!!
    // TODO: statfs to see if attribute is meaningful
    // TODO: consider opening file for writing first and then use fxxx functions to change attrs - it may be faster
    // TODO: need an additional checkbox to work with symlinks.
    
    // stat current file. no stat - no change.
    struct stat st;
    if(stat(_full_path, &st) != 0)
    {
        // TODO: error. handle it somehow? maybe ask for super-user rights?
        return;
    }
    
    // process unix access modes
    mode_t newmode = st.st_mode;
#define DOACCESS(_f, _c)\
    if(m_Command->flags[FileSysAttrAlterCommand::_f] == FileSysAttrAlterCommand::fsf_on) newmode |= _c;\
    if(m_Command->flags[FileSysAttrAlterCommand::_f] == FileSysAttrAlterCommand::fsf_off) newmode &= ~_c;
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
        int res = chmod(_full_path, newmode);
        if(res != 0 && !m_SkipAllErrors)
        {
            int result = [[m_Operation DialogChmodError:errno
                                                ForFile:_full_path
                                               WithMode:newmode] WaitForResult];
            
            if (result == OperationDialogResultStop)
            {
                SetStopped();
                return;
            }
            if (result == FileSysAttrChangeOperationDialogSkipAll)
                m_SkipAllErrors = true;
            
            // TODO: error handling
        }
    }
    
    // process file flags
    uint32_t newflags = st.st_flags;
#define DOFLAGS(_f, _c)\
    if(m_Command->flags[FileSysAttrAlterCommand::_f] == FileSysAttrAlterCommand::fsf_on) newflags |= _c;\
    if(m_Command->flags[FileSysAttrAlterCommand::_f] == FileSysAttrAlterCommand::fsf_off) newflags &= ~_c;
    DOFLAGS(fsf_uf_nodump, UF_NODUMP);
    DOFLAGS(fsf_uf_immutable, UF_IMMUTABLE);
    DOFLAGS(fsf_uf_append, UF_APPEND);
    DOFLAGS(fsf_uf_opaque, UF_OPAQUE);
    DOFLAGS(fsf_uf_hidden, UF_HIDDEN);
    DOFLAGS(fsf_sf_archived, SF_ARCHIVED);
    DOFLAGS(fsf_sf_immutable, SF_IMMUTABLE);
    DOFLAGS(fsf_sf_append, SF_APPEND);
#undef DOFLAGS
    if(newflags != st.st_flags)
    {
        int res = chflags(_full_path, newflags);
        if(res != 0)
        {
            // TODO: error handling
        }
    }
        
    // process file owner and file group
    uid_t newuid = st.st_uid;
    gid_t newgid = st.st_gid;
    if(m_Command->set_uid) newuid = m_Command->uid;
    if(m_Command->set_gid) newgid = m_Command->gid;
    if(newuid != st.st_uid || newgid != st.st_gid)
    {
        int res = chown(_full_path, newuid, newgid); // NEED super-user rights here, regular rights are useless almost always
        if(res != 0)
        {
            // TODO: error handling
        }
    }
    
    // process file times
    // TODO: still weirdness with timezone stuff

    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;

    if(m_Command->set_atime && m_Command->atime != st.st_atimespec.tv_sec)
    {
        attrs.commonattr = ATTR_CMN_ACCTIME;
        timespec time = {m_Command->atime, 0}; // yep, no msec and nsec
        int res = setattrlist(_full_path, &attrs, &time, sizeof(time), 0);
        if(res != 0)
        {
            // TODO: error handling
        }
    }

    if(m_Command->set_mtime && m_Command->mtime != st.st_mtimespec.tv_sec)
    {
        attrs.commonattr = ATTR_CMN_MODTIME;
        timespec time = {m_Command->mtime, 0}; // yep, no msec and nsec
        int res = setattrlist(_full_path, &attrs, &time, sizeof(time), 0);
        if(res != 0)
        {
            // TODO: error handling
        }
    }
    
    if(m_Command->set_ctime && m_Command->ctime != st.st_ctimespec.tv_sec)
    {
        attrs.commonattr = ATTR_CMN_CHGTIME;
        timespec time = {m_Command->ctime, 0}; // yep, no msec and nsec
        int res = setattrlist(_full_path, &attrs, &time, sizeof(time), 0);
        if(res != 0)
        {
            // TODO: error handling
        }
    }
    
    if(m_Command->set_btime && m_Command->btime != st.st_birthtimespec.tv_sec)
    {
        attrs.commonattr = ATTR_CMN_CRTIME;
        timespec time = {m_Command->btime, 0}; // yep, no msec and nsec
        int res = setattrlist(_full_path, &attrs, &time, sizeof(time), 0);
        if(res != 0)
        {
            // TODO: error handling
        }
    }
}