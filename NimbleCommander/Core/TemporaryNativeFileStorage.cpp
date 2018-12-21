// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <sys/param.h>
#include <dirent.h>
#include <ftw.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include <Utility/PathManip.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "TemporaryNativeFileStorage.h"
#include <thread>
#include <Habanero/dispatch_cpp.h>

using namespace std::literals;

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

static const std::string g_Pref = nc::bootstrap::ActivationManager::BundleID() + ".tmp.";

static void DoTempPurge();

static int Extract(
                   const char *_vfs_path,
                   VFSHost &_host,
                   const char *_native_path)
{
    VFSFilePtr vfs_file;
    int ret = _host.CreateFile(_vfs_path, vfs_file, 0);
    if( ret < 0)
        return ret;
    
    ret = vfs_file->Open(VFSFlags::OF_Read);
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
                ret = (int)res_write;
                goto error;
            }
        }
    }
    if(res_read < 0) {
        ret = (int)res_read;
        goto error;
    }
    
    { // xattrs stuff
        vfs_file->XAttrIterateNames([&](const char *name) -> bool{
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
    std::thread(DoTempPurge).detach();
    
    auto tmp_1st = NewTempDir();
    if(!tmp_1st.empty())
        m_SubDirs.emplace_back(tmp_1st);
}

TemporaryNativeFileStorage::~TemporaryNativeFileStorage()
{ /* never called */ }

TemporaryNativeFileStorage &TemporaryNativeFileStorage::Instance()
{
    static TemporaryNativeFileStorage *g_SharedInstance = new TemporaryNativeFileStorage;
    return *g_SharedInstance;
}

std::string TemporaryNativeFileStorage::NewTempDir()
{
    char pattern_buf[MAXPATHLEN];
    sprintf(pattern_buf, "%s%sXXXXXX", CommonPaths::AppTemporaryDirectory().c_str(), g_Pref.c_str());
    char *res = mkdtemp(pattern_buf);
    if(res == 0)
        return {};
    if(pattern_buf[strlen(pattern_buf)-1] != '/')
        strcat(pattern_buf, "/");
    return pattern_buf;
}

bool TemporaryNativeFileStorage::GetSubDirForFilename(const char *_filename, char *_full_path)
{
    // check currently owned directories for being able to hold such filename (no collisions)
    std::lock_guard<std::mutex> lock(m_SubDirsLock);
    bool found = false;
    retry:
    for(auto i = begin(m_SubDirs), e = end(m_SubDirs); i != e; ++i) {
        // check current tmp sub-directory
        struct stat st;
        if( lstat(i->c_str(), &st) != 0 ) {
            m_SubDirs.erase(i); // remove bad temp subdirectory from our catalog
            goto retry;
        }
            
        char tmp[MAXPATHLEN];
        strcpy(tmp, i->c_str());
        strcat(tmp, _filename);
            
        // check for presence of _filename in current sub-dir
        if( lstat(tmp, &st) != 0 ) {
            // no such file, ok to use
            strcpy(_full_path, i->c_str());
            found = true;
        }
    }
    
    if(found) return true;
    
    // create a new dir and return combined path
    auto newdir = NewTempDir();
    if( !newdir.empty() ) {
        m_SubDirs.emplace_back(newdir);
        strcpy(_full_path, newdir.c_str());
        return true;
    }
    return false; // something is very bad with whole system
}

std::optional<std::string>
    TemporaryNativeFileStorage::WriteStringIntoTempFile( const std::string& _source)
{
    std::string filename;
    for(int i = 0; i < 6; ++i)
        filename += 'A' + rand() % ('Z'-'A');
    
    char path[MAXPATHLEN];
    if( !GetSubDirForFilename(filename.c_str(), path) )
        return std::nullopt;
    strcat(path, filename.c_str());
    
    int fd = open(path, O_EXLOCK|O_NONBLOCK|O_RDWR|O_CREAT, S_IRUSR|S_IWUSR);
    if(fd < 0)
        return std::nullopt;
    auto close_fd = at_scope_end([=]{ close(fd); });
    
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    
    const char *buf = _source.c_str();
    ssize_t left = _source.length();
    while( left > 0 ) {
        ssize_t res_write = write( fd, buf, left );
        if( res_write >= 0 ) {
            left -= res_write;
            buf += res_write;
        }
        else {
            unlink(path);
            return std::nullopt;
        }
    }
   
    return std::string(path);
}

std::optional<std::string>
    TemporaryNativeFileStorage::CopySingleFile(const std::string &_vfs_filepath, VFSHost &_host)
{
    VFSFilePtr vfs_file;
    if( _host.CreateFile(_vfs_filepath.c_str(), vfs_file, 0) < 0 )
        return std::nullopt;

    if( vfs_file->Open(VFSFlags::OF_Read) < 0 )
        return std::nullopt;
    
    char name[MAXPATHLEN];
    if( !GetFilenameFromPath(_vfs_filepath.c_str(), name) )
        return std::nullopt;
    
    char native_path[MAXPATHLEN];
    if( !GetSubDirForFilename(name, native_path) )
       return std::nullopt;
    strcat(native_path, name);
    
    int fd = open(native_path, O_EXLOCK|O_NONBLOCK|O_RDWR|O_CREAT, S_IRUSR|S_IWUSR);
    if( fd < 0 )
        return std::nullopt;
    
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    
    const size_t bufsz = 256*1024;
    char buf[bufsz], *bufp = buf;
    ssize_t res_read;
    while( (res_read = vfs_file->Read(buf, bufsz)) > 0 ) {
        ssize_t res_write;
        bufp = buf;
        while(res_read > 0) {
            res_write = write(fd, bufp, res_read);
            if(res_write >= 0) {
                res_read -= res_write;
                bufp += res_write;
            }
            else
                goto error;
        }
    }
    if(res_read < 0)
        goto error;
    
    { // xattrs stuff
        vfs_file->XAttrIterateNames(^bool(const char *_name){
            ssize_t res = vfs_file->XAttrGet(_name, bufp, bufsz);
            if(res >= 0)
                fsetxattr(fd, _name, bufp, res, 0, 0);
            return true;
        });
    }
    
    close(fd);
    return std::string(native_path);
    
error:
    close(fd);
    unlink(native_path);
    return std::nullopt;
}

bool TemporaryNativeFileStorage::CopyDirectory(const std::string &_vfs_dirpath,
                                               const VFSHostPtr &_host,
                                               uint64_t _max_total_size,
                                               std::function<bool()> _cancel_checker,
                                               std::string &_tmp_dirpath)
{
    // this is not a-best-of-all implementation.
    // supposed that temp extraction of dirs would be rare thus with much less pressure that extracting of single files
    
    VFSStat st_src_dir;
    if( _host->Stat(_vfs_dirpath.c_str(), st_src_dir, 0, 0) != 0)
        return false;
    
    if( !st_src_dir.mode_bits.dir )
        return false;
    
    uint64_t total_size = 0;
    
    struct S {
        inline S(const boost::filesystem::path &_src_path,
                 const boost::filesystem::path &_rel_path,
                 const VFSStat& _st):
            src_path(_src_path),
            rel_path(_rel_path),
            st(_st)
        {}
        boost::filesystem::path src_path;
        boost::filesystem::path rel_path;
        VFSStat st;
    };
    
    boost::filesystem::path vfs_dirpath = _vfs_dirpath;
    std::string top_level_name = vfs_dirpath.filename() == "." ?
        vfs_dirpath.parent_path().filename().native() :
        vfs_dirpath.filename().native();
    
    // traverse source structure
    std::vector< S > src;
    std::stack< S > traverse_log;
    
    src.emplace_back(_vfs_dirpath, top_level_name, st_src_dir);
    
    traverse_log.push(src.back());
    while( !traverse_log.empty() ) {
        auto last = traverse_log.top();
        boost::filesystem::path dir_path = last.src_path;
        traverse_log.pop();
        
        int res = _host->IterateDirectoryListing(dir_path.c_str(), [&](const VFSDirEnt &_dirent) {
            if( _cancel_checker && _cancel_checker() )
                return false;
            
            boost::filesystem::path cur = dir_path / _dirent.name;
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
        
        auto p = boost::filesystem::path(native_path) / i.rel_path;
        
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
    
    _tmp_dirpath = (boost::filesystem::path(native_path) / top_level_name).native();
    
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
    DIR *dirp = opendir(CommonPaths::AppTemporaryDirectory().c_str());
    if(!dirp)
        return;
    
    dirent *entp;
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
        if(
           entp->d_namlen >= g_Pref.length() &&
           entp->d_type == DT_DIR &&
           strncmp(entp->d_name, g_Pref.c_str(), g_Pref.length()) == 0
           )
        {
            char fn[MAXPATHLEN];
            strcpy(fn, CommonPaths::AppTemporaryDirectory().c_str());
            strcat(fn, entp->d_name);
            strcat(fn, "/");
            
            if(DoSubDirPurge(fn))
                rmdir(fn); // if temp directory is empty - remove it
        }
    
    closedir(dirp);
    
    // schedule next purging in 6 hours
    dispatch_after(6h, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), []{
        DoTempPurge();
    });
}
