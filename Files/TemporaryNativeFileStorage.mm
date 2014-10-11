//
//  TemporaryNativeFilesStorage.mm
//  Files
//
//  Created by Michael G. Kazakov on 03.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <sys/xattr.h>
#import <dirent.h>
#import "TemporaryNativeFileStorage.h"
#import "Common.h"

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

static const string g_Pref = __FILES_IDENTIFIER__".tmp.";
static const string g_TempDir = NSTemporaryDirectory().fileSystemRepresentation;

static int Extract(
                   const char *_vfs_path,
                   VFSHost &_host,
                   const char *_native_path)
{
    VFSFilePtr vfs_file;
    int ret = _host.CreateFile(_vfs_path, vfs_file, 0);
    if( ret < 0)
        return ret;
    
    ret = vfs_file->Open(VFSFile::OF_Read);
    if( ret < 0)
        return ret;
    
    int fd = open(_native_path, O_EXLOCK|O_NONBLOCK|O_RDWR|O_CREAT, S_IRUSR|S_IWUSR);
    if(fd < 0)
        return VFSError::FromErrno();
    
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    
    const size_t bufsz = 256*1024;
    char buf[bufsz], *bufp = buf;
    ssize_t res_read;
    while( (res_read = vfs_file->Read(buf, bufsz)) > 0 ) {
        ssize_t res_write;
        while(res_read > 0) {
            res_write = write(fd, buf, res_read);
            if(res_write >= 0)
                res_read -= res_write;
            else {
                goto error;
                ret = (int)res_write;
            }
        }
    }
    if(res_read < 0) {
        ret = (int)res_read;
        goto error;
    }
    
    { // xattrs stuff
        vfs_file->XAttrIterateNames(^bool(const char *name){
            ssize_t res = vfs_file->XAttrGet(name, bufp, bufsz);
            if(res >= 0)
                fsetxattr(fd, name, bufp, res, 0, 0);
            return true;
        });
    }
    
    close(fd);
    return 0;
    
error:
    close(fd);
    unlink(_native_path);
    return ret;
}

static int unlink_cb(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf)
{
    if( typeflag == FTW_F)
        unlink(fpath);
    else if( typeflag == FTW_D   ||
             typeflag == FTW_DNR ||
             typeflag == FTW_DP   )
        rmdir(fpath);
    return 0;
}

static int rmrf(char *path)
{
    return nftw(path, unlink_cb, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
}

TemporaryNativeFileStorage::TemporaryNativeFileStorage()
{
    m_ControlQueue = dispatch_queue_create(__FILES_IDENTIFIER__".TemporaryNativeFileStorage", NULL);
    
    char tmp_1st[MAXPATHLEN];
    if(NewTempDir(tmp_1st))
        m_SubDirs.push_back(tmp_1st);
}

TemporaryNativeFileStorage::~TemporaryNativeFileStorage()
{ /* never called */ }

TemporaryNativeFileStorage &TemporaryNativeFileStorage::Instance()
{
    static TemporaryNativeFileStorage *g_SharedInstance = new TemporaryNativeFileStorage;
    return *g_SharedInstance;
}

bool TemporaryNativeFileStorage::NewTempDir(char *_full_path)
{
    char pattern_buf[MAXPATHLEN];
    sprintf(pattern_buf, "%s%sXXXXXX", g_TempDir.c_str(), g_Pref.c_str());
    char *res = mkdtemp(pattern_buf);
    if(res == 0)
        return false;
    if(pattern_buf[strlen(pattern_buf)-1] != '/')
        strcat(pattern_buf, "/");
    strcpy(_full_path, pattern_buf);
    return true;
}

bool TemporaryNativeFileStorage::GetSubDirForFilename(const char *_filename, char *_full_path)
{
    // check currently owned directories for being able to hold such filename (no collisions)
    __block bool found = false;;
    dispatch_sync(m_ControlQueue, ^{ // over-locking here. TODO: consider another algo
    retry:
        for(auto i = m_SubDirs.begin(); i != m_SubDirs.end(); ++i)
        {
            // check current tmp sub-directory
            struct stat st;
            if( lstat(i->c_str(), &st) != 0 )
            {
                m_SubDirs.erase(i); // remove bad temp subdirectory from our catalog
                goto retry;
            }
            
            char tmp[MAXPATHLEN];
            strcpy(tmp, i->c_str());
            strcat(tmp, _filename);
            
            // check for presence of _filename in current sub-dir
            if( lstat(tmp, &st) != 0 )
            {
                // no such file, ok to use
                strcpy(_full_path, i->c_str());
                found = true;
            }
        }
    });
    
    if(found) return true;
    
    // create a new dir and return combined path
    char newdir[MAXPATHLEN];
    if(NewTempDir(newdir))
    {
        string newdirs = newdir;
        dispatch_sync(m_ControlQueue, ^{ m_SubDirs.push_back(newdirs); });
        strcpy(_full_path, newdir);
        return true;
    }
    return false; // something is very bad with whole system
}

bool TemporaryNativeFileStorage::CopySingleFile(const string &_vfs_filepath,
                                                const VFSHostPtr &_host,
                                                string& _tmp_filename
                                                )
{
    VFSFilePtr vfs_file;
    if(_host->CreateFile(_vfs_filepath.c_str(), vfs_file, 0) < 0)
        return false;

    if(vfs_file->Open(VFSFile::OF_Read) < 0)
        return false;
    
    char name[MAXPATHLEN];
    if(!GetFilenameFromPath(_vfs_filepath.c_str(), name))
        return false;
    
    char native_path[MAXPATHLEN];
    if(!GetSubDirForFilename(name, native_path))
       return false;
    strcat(native_path, name);
    
    int fd = open(native_path, O_EXLOCK|O_NONBLOCK|O_RDWR|O_CREAT, S_IRUSR|S_IWUSR);
    if(fd < 0)
        return false;
    
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    
    const size_t bufsz = 256*1024;
    char buf[bufsz], *bufp = buf;
    ssize_t res_read;
    while( (res_read = vfs_file->Read(buf, bufsz)) > 0 ) {
        ssize_t res_write;
        while(res_read > 0) {
            res_write = write(fd, buf, res_read);
            if(res_write >= 0)
                res_read -= res_write;
            else
                goto error;
        }
    }
    if(res_read < 0)
        goto error;
    
    { // xattrs stuff
        vfs_file->XAttrIterateNames(^bool(const char *name){
            ssize_t res = vfs_file->XAttrGet(name, bufp, bufsz);
            if(res >= 0)
                fsetxattr(fd, name, bufp, res, 0, 0);
            return true;
        });
    }
    
    close(fd);
    
    _tmp_filename = native_path;
    return true;
    
error:
    close(fd);
    unlink(native_path);
    return false;
}

bool TemporaryNativeFileStorage::CopyDirectory(const string &_vfs_dirpath,
                                               const VFSHostPtr &_host,
                                               uint64_t _max_total_size,
                                               function<bool()> _cancel_checker,
                                               string &_tmp_dirpath)
{
    // this is not a-best-of-all implementation.
    // supposed that temp extraction of dirs would be rare thus with much less pressure that extracting of single files
    
    VFSStat st;
    if( _host->Stat(_vfs_dirpath.c_str(), st, 0, 0) != 0)
        return false;
    
    if( !st.mode_bits.dir )
        return false;
    
    uint64_t total_size = 0;
    
    struct S {
        inline S(const path &_src_path, const path &_rel_path, const VFSStat& _st):
            src_path(_src_path),
            rel_path(_rel_path),
            st(_st)
        {}
        path src_path;
        path rel_path;
        VFSStat st;
    };
    
    path vfs_dirpath = _vfs_dirpath;
    string top_level_name = vfs_dirpath.filename() == "." ?
        vfs_dirpath.parent_path().filename().native() :
        vfs_dirpath.filename().native();
    
    // traverse source structure
    vector< S > src;
    stack< S > traverse_log;
    
    src.emplace_back(_vfs_dirpath, top_level_name, st);
    
    traverse_log.push(src.back());
    while( !traverse_log.empty() ) {
        auto last = traverse_log.top();
        path dir_path = last.src_path;
        traverse_log.pop();
        
        int res = _host->IterateDirectoryListing(dir_path.c_str(), [&](const VFSDirEnt &_dirent) {
            if( _cancel_checker && _cancel_checker() )
                return false;
            
            path cur = dir_path / _dirent.name;
            VFSStat st;
            if( _host->Stat(cur.c_str(), st, 0, 0) != 0 )
                return false; // break directory iterating on any error
            
            src.emplace_back(cur, last.rel_path / _dirent.name, st);
            if( st.mode_bits.dir )
                traverse_log.push(src.back());
            else
                total_size += st.size;
            
            if(total_size > _max_total_size)
                return false;
            
            return true;
        });

        if(res != 0 || total_size > _max_total_size)
            return false;
    }
    
    // build holding top-level directory
    char native_path[MAXPATHLEN];
    if(!GetSubDirForFilename(top_level_name.c_str(), native_path))
        return false;
    
    // extraction itself
    for( const auto &i: src ) {
        if( _cancel_checker && _cancel_checker() )
            return false;
        
        path p = path(native_path) / i.rel_path;
        
        if( i.st.mode_bits.dir ) {
            if(mkdir(p.c_str(), 0700) != 0)
                return false;
            // todo: xattrs
/*            vector<pair<string,vector<uint8_t>>> xattrs;
            _host->GetXAttrs(i.src_path.c_str(), xattrs);
            for(auto &xa: xattrs)
                setxattr(p.c_str(), xa.first.c_str(), xa.second.data(), xa.second.size(), 0, 0); */        
        }
        else {
            int rc = Extract(i.src_path.c_str(), *_host, p.c_str());
            if(rc != 0)
                return false;
        }
    }
    
    _tmp_dirpath = (path(native_path) / top_level_name).native();
    
    return true;
}


// return true if directory is empty after this function call
static bool DoSubDirPurge(const char *_dir)
{
    DIR *dirp = opendir(_dir);
    if(!dirp)
        return false;
    
    int filesnum = 0;
    
    dirent *entp;
    while((entp = _readdir_unlocked(dirp, 1)) != NULL) {
        if(strcmp(entp->d_name, ".") == 0 || strcmp(entp->d_name, "..") == 0 ) continue;

        filesnum++;
        
        char tmp[MAXPATHLEN];
        strcpy(tmp, _dir);
        strcat(tmp, entp->d_name);
        
        struct stat st;
        if( lstat(tmp, &st) == 0 ) {
            time_t tdiff = st.st_mtimespec.tv_sec - time(nullptr);
            if( S_ISREG(st.st_mode) ) {
                if(tdiff < -60*60*24 && unlink(tmp) == 0) // delete every file older than 24 hours
                    filesnum--;
            }
            else if( S_ISDIR(st.st_mode) ) {
                if(tdiff < -60*60*24 && rmrf(tmp) == 0)  // delete every file older than 24 hours
                    filesnum--;
            }
        }
    }
    closedir(dirp);
    return filesnum == 0;
}

static void DoTempPurge()
{
    DIR *dirp = opendir(g_TempDir.c_str());
    if(!dirp)
        return;
    
    dirent *entp;
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
        if( strncmp(entp->d_name, g_Pref.c_str(), g_Pref.length()) == 0 &&
           entp->d_type == DT_DIR
           )
        {
            char fn[MAXPATHLEN];
            strcpy(fn, g_TempDir.c_str());
            strcat(fn, entp->d_name);
            strcat(fn, "/");
            
            if(DoSubDirPurge(fn))
                rmdir(fn); // if temp directory is empty - remove it
        }
    
    closedir(dirp);
    
    // schedule next purging in 6 hours
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60*60*6*NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       DoTempPurge();
                   });
}

void TemporaryNativeFileStorage::StartBackgroundPurging()
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        DoTempPurge();
    });
}
