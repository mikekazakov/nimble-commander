//
//  VFSArchiveHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSArchiveHost.h"
#import <assert.h>


#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSArchiveInternal.h"
#import "VFSArchiveFile.h"
#import "VFSArchiveListing.h"

VFSArchiveHost::VFSArchiveHost(const char *_junction_path,
                               std::shared_ptr<VFSHost> _parent):
    VFSHost(_junction_path, _parent),
    m_Arc(0)
{
/*    int res = Parent()->CreateFile(_junction_path, &m_ArFile, nil);
    assert(res == VFSError::Ok);
    res = m_ArFile->Open(VFSFile::OF_Read);
    assert(res == VFSError::Ok);

    m_Mediator = std::make_shared<VFSArchiveMediator>();
    m_Mediator->file = m_ArFile;
    
    
    struct archive *a;
    struct archive_entry *entry;
    a = archive_read_new();
    archive_read_support_compression_all(a);
    archive_read_support_format_all(a);
    
    archive_read_set_callback_data(a, m_Mediator.get());
    archive_read_set_read_callback(a, VFSArchiveMediator::myread);
    archive_read_set_seek_callback(a, VFSArchiveMediator::myseek);
    archive_read_open1(a);
    
//    __LA_DECL int archive_read_set_seek_callback(struct archive *,
//                                                 archive_seek_callback *);
    
    
    while (archive_read_next_header(a, &entry) == ARCHIVE_OK)
    {
        const char *path = archive_entry_pathname(entry);
        const struct stat *stat = archive_entry_stat(entry);
        
        long sz = archive_entry_size(entry);
        
        printf("%s, size %ld\n", path, sz);
    }
    archive_read_free(a);*/
//    free(mydata);
}

VFSArchiveHost::~VFSArchiveHost()
{
    if(m_Arc != 0)
        archive_read_free(m_Arc);
    for(auto &i: m_PathToDir)
        delete i.second;
}

int VFSArchiveHost::Open()
{
    assert(m_Arc == 0);

    int res = Parent()->CreateFile(JunctionPath(), &m_ArFile, nil);
    if(res < 0)
        return res;
    
    if(m_ArFile->GetReadParadigm() < VFSFile::ReadParadigm::Seek)
    {
        m_ArFile.reset();
        return VFSError::InvalidCall;
    }
    
    res = m_ArFile->Open(VFSFile::OF_Read);
    if(res < 0)
        return res;
    
    m_Mediator = std::make_shared<VFSArchiveMediator>();
    m_Mediator->file = m_ArFile;
    
    m_Arc = archive_read_new();
//    archive_read_support_compression_all(m_Arc);
    archive_read_support_filter_all(m_Arc);
    archive_read_support_format_all(m_Arc);
    
    archive_read_set_callback_data(m_Arc, m_Mediator.get());
    archive_read_set_read_callback(m_Arc, VFSArchiveMediator::myread);
    archive_read_set_seek_callback(m_Arc, VFSArchiveMediator::myseek);
    res = archive_read_open1(m_Arc);
    if(res < 0)
    {
        archive_read_free(m_Arc);
        m_Arc = 0;
        m_Mediator.reset();
        m_ArFile.reset();
        return -1; // TODO: right error code
    }
    
    res = ReadArchiveListing();
    
    
    return res;
}

int VFSArchiveHost::ReadArchiveListing()
{
    assert(m_Arc != 0);
    
    VFSArchiveDir *root = new VFSArchiveDir;
    root->full_path = "/";
    root->name_in_parent  = "";
    m_PathToDir.insert(std::make_pair("/", root));

    VFSArchiveDir *parent_dir = root;
    struct archive_entry *entry;
    int ret;
    while ((ret = archive_read_next_header(m_Arc, &entry)) == ARCHIVE_OK)
    {
        const struct stat *stat = archive_entry_stat(entry);
        char path[1024];
        path[0] = '/';
        strcpy(path + 1, archive_entry_pathname(entry));
        
//        printf("%s\n", path);
        
        int path_len = (int)strlen(path);
        
//        bool isdir = path[path_len-1] == '/';
        bool isdir = (stat->st_mode & S_IFMT) == S_IFDIR;
        
//        archive_read_data
        char short_name[256];
        char parent_path[1024];
        {
            char tmp[1024];
            strcpy(tmp, path);
            if(tmp[path_len-1] == '/') // cut trailing slash if any
                tmp[path_len-1] = 0;
            char *last_slash = strrchr(tmp, '/');
            strcpy(short_name, last_slash+1);
            *(last_slash+1)=0;
            strcpy(parent_path, tmp);
        }
        
        if(parent_dir->full_path != parent_path)
            parent_dir = FindOrBuildDir(parent_path);
        
        VFSArchiveDirEntry *entry = 0;
        if(isdir) // check if it wasn't added before via FindOrBuildDir
            for(auto &it: parent_dir->entries)
                if( (it.st.st_mode & S_IFMT) == S_IFDIR && it.name == short_name) {
                    entry = &it;
                    break;
                }
        
        if(entry == 0) {
            parent_dir->entries.push_back(VFSArchiveDirEntry());
            entry = &parent_dir->entries.back();
            entry->name = short_name;
        }

        entry->st = *stat;
        
        if(isdir)
        {
            // it's a directory
            if(m_PathToDir.find(path) == m_PathToDir.end())
            { // check if it wasn't added before via FindOrBuildDir
                char tmp[1024];
                strcpy(tmp, path);
                tmp[path_len-1] = 0;
                VFSArchiveDir *dir = new VFSArchiveDir;
                dir->full_path = path; // full_path is with trailing slash
                dir->name_in_parent = strrchr(tmp, '/')+1;
                m_PathToDir.insert(std::make_pair(path, dir));
            }
        }
    }
    
    if(ret == ARCHIVE_EOF)
        return VFSError::Ok;

    printf("%s\n", archive_error_string(m_Arc));
    
    return VFSError::GenericError;
}

VFSArchiveDir* VFSArchiveHost::FindOrBuildDir(const char* _path_with_tr_sl)
{
    assert(_path_with_tr_sl[strlen(_path_with_tr_sl)-1] == '/');
    auto i = m_PathToDir.find(_path_with_tr_sl);
    if(i != m_PathToDir.end())
        return (*i).second;
    
    char entry_name[256];
    char parent_path[1024];
    strcpy(parent_path, _path_with_tr_sl);
    parent_path[strlen(parent_path)-1] = 0;
    strcpy(entry_name, strrchr(parent_path, '/')+1);
    *(strrchr(parent_path, '/')+1) = 0;
    
    auto parent_dir = FindOrBuildDir(parent_path);

//    printf("FindOrBuildDir: adding new dir %s\n", _path_with_tr_sl);
    
    InsertDummyDirInto(parent_dir, entry_name);
    VFSArchiveDir *entry = new VFSArchiveDir;
    entry->full_path = _path_with_tr_sl;
    entry->name_in_parent  = entry_name;
    auto i2 = m_PathToDir.insert(std::make_pair(_path_with_tr_sl, entry));
    return (*i2.first).second;
}

void VFSArchiveHost::InsertDummyDirInto(VFSArchiveDir *_parent, const char* _dir_name)
{
    _parent->entries.push_back(VFSArchiveDirEntry());
    auto &entry = _parent->entries.back();
    entry.name = _dir_name;
    memset(&entry.st, 0, sizeof(entry.st));
    entry.st.st_mode = S_IFDIR;
}

struct archive* VFSArchiveHost::Archive()
{
    return m_Arc;
}

std::shared_ptr<VFSFile> VFSArchiveHost::ArFile() const
{
    return m_ArFile;
}

int VFSArchiveHost::CreateFile(const char* _path,
                       std::shared_ptr<VFSFile> *_target,
                       bool (^_cancel_checker)())
{
    auto file = std::make_shared<VFSArchiveFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    *_target = file;
    return VFSError::Ok;
}

int VFSArchiveHost::FetchDirectoryListing(const char *_path,
                                  std::shared_ptr<VFSListing> *_target,
                                  bool (^_cancel_checker)())
{
    char path[1024];
    strcpy(path, _path);
    if(path[strlen(path)-1] != '/')
        strcat(path, "/");
    
    
    auto i = m_PathToDir.find(path);
    if(i == m_PathToDir.end())
        return VFSError::NotFound;

    std::shared_ptr<VFSArchiveListing> listing = std::make_shared<VFSArchiveListing>
        (i->second, path, SharedPtr());
    
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    *_target = listing;
    
    return VFSError::Ok;
}