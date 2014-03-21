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

static TemporaryNativeFileStorage *g_SharedInstance = 0;
static const char *g_Pref = "info.filesmanager.tmp.";
static const size_t g_PrefLen = strlen(g_Pref);
static char g_TmpDirPath[MAXPATHLEN] = {0}; // will be temp dir with trailing slash

TemporaryNativeFileStorage::TemporaryNativeFileStorage()
{
    m_ControlQueue = dispatch_queue_create("info.filesmanager.Files.TemporaryNativeFileStorage", NULL);
    
    char tmp_1st[MAXPATHLEN];
    if(NewTempDir(tmp_1st))
        m_SubDirs.push_back(tmp_1st);
}

TemporaryNativeFileStorage::~TemporaryNativeFileStorage()
{ /* never called */ }

TemporaryNativeFileStorage &TemporaryNativeFileStorage::Instance()
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_SharedInstance = new TemporaryNativeFileStorage;
    });
    return *g_SharedInstance;
}

bool TemporaryNativeFileStorage::NewTempDir(char *_full_path)
{
    char pattern_buf[MAXPATHLEN];
    sprintf(pattern_buf, "%s%sXXXXXX", g_TmpDirPath, g_Pref);
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
                strcpy(_full_path, tmp);
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
        strcat(newdir, _filename);
        strcpy(_full_path, newdir);
        return true;
    }
    return false; // something is very bad with whole system
}

bool TemporaryNativeFileStorage::CopySingleFile(const char* _vfs_filename,
                                                shared_ptr<VFSHost> _host,
                                                char *_tmp_filename
                                                )
{
    VFSFilePtr vfs_file;
    if(_host->CreateFile(_vfs_filename, vfs_file, 0) < 0)
        return false;

    if(vfs_file->Open(VFSFile::OF_Read) < 0)
        return false;
    
    char name[MAXPATHLEN];
    if(!GetFilenameFromPath(_vfs_filename, name))
        return false;
    
    char native_path[MAXPATHLEN];
    if(!GetSubDirForFilename(name, native_path))
       return false;
    
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
    
    strcpy(_tmp_filename, native_path);
    return true;
    
error:
    close(fd);
    unlink(native_path);
    return false;
}


// return true if directory is empty after this function call
static bool DoSubDirPurge(const char *_dir)
{
    DIR *dirp = opendir(_dir);
    if(!dirp)
        return false;
    
    int filesnum = 0;
    
    dirent *entp;
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
    {
        if(strcmp(entp->d_name, ".") == 0 || strcmp(entp->d_name, "..") == 0 ) continue;

        filesnum++;
        
        char tmp[MAXPATHLEN];
        strcpy(tmp, _dir);
        strcat(tmp, entp->d_name);
        
        struct stat st;
        if( lstat(tmp, &st) == 0 )
        {
            if( S_ISREG(st.st_mode) )
            {
                NSDate *file_date = [NSDate dateWithTimeIntervalSince1970:st.st_mtimespec.tv_sec];
                NSTimeInterval diff = [file_date timeIntervalSinceNow];
                if(diff < -60*60*24 && unlink(tmp) == 0) // delete every file older than 24 hours
                    filesnum--;
            }
            else if( S_ISDIR(st.st_mode) )
            {
                // TODO: implement me later
            }
        }
    }
    closedir(dirp);
    return filesnum == 0;
}

static void DoTempPurge()
{
    DIR *dirp = opendir(g_TmpDirPath);
    if(!dirp)
        return;
    
    dirent *entp;
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
        if( strncmp(entp->d_name, g_Pref, g_PrefLen) == 0 &&
           entp->d_type == DT_DIR
           )
        {
            char fn[MAXPATHLEN];
            strcpy(fn, g_TmpDirPath);
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
    // also initialize some stuff
    NSString *temp_dir = NSTemporaryDirectory();
    assert(temp_dir);
    strcpy(g_TmpDirPath, [temp_dir fileSystemRepresentation]);
    if(g_TmpDirPath[strlen(g_TmpDirPath)-1] != '/')
        strcat(g_TmpDirPath, "/");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        DoTempPurge();
    });
}
