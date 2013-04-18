#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <sys/dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <deque> // STL is a temporary solution, should be removed later
#include <stdlib.h>
#include <time.h>

// working in 64bit environment - keep in mind


// used for directories before it's size become known
#define DIRENTINFO_INVALIDSIZE (0xFFFFFFFFFFFFFFFFu)

struct DirectoryEntryCustomFlags
{
    enum
    {
        Selected = 1<<0
    };
};

struct DirectoryEntryInformation // 128b long
{
    // #0
    unsigned char  namebuf[14];             // UTF-8, including null-term. if namelen >13 => (char**)&name[0] is a buffer from malloc for namelen+1 bytes
    // #14
    unsigned short namelen;                 // not-including null-term
    // #16
    unsigned long  ino;                     // 64b-long inode number
    // #24
    unsigned long  size;                    // file size. initial 0xFFFFFFFFFFFFFFFFu for directories, other value means calculated directory size
    // #32
    time_t         atime;                   // time of last access. we're dropping st_atimespec.tv_nsec information
    // #40
    time_t         mtime;                   // time of last data modification. we're dropping st_mtimespec.tv_nsec information
    // #48
    time_t         ctime;                   // time of last status change (data modification OR access changes, hardlink changes etc). we're dropping st_ctimespec.tv_nsec information
    // #56
    time_t         btime;                   // time of file creation(birth). we're dropping st_birthtimespec.tv_nsec information
    // #64
    unsigned int   cflags;                  // custom flags. volatile - can be changed. up to 32 flags
    // #68
    mode_t         unix_mode;               // file type from stat
    // #72
    CFStringRef    cf_name;                 // it's a string created with CFStringCreateWithBytesNoCopy, pointing at name()
    // #80
    const char     *symlink;                // a pointer to symlink's value or NULL if entry is not a symlink or an error has occured
    // #88
    uint32_t       unix_flags;              // st_flags field from stat, see chflags(2)
    // #92
    uid_t          unix_uid;                // user ID of the file
    // #96
    gid_t          unix_gid;                // group ID of the file
    // #100
    unsigned short extoffset;               // extension of a file if any. 0 if there's no extension, or position of a first char of an extention
    // #102
    unsigned char  unix_type;               // file type from <sys/dirent.h> (from readdir)
    // #103
    unsigned char  ___padding[25];
    // #128

    inline void destroy()
    {
        CFRelease(cf_name);
        if(symlink != 0)
            free((void*)symlink);
        if(namelen > 13)
            free((void*)*(const unsigned char**)(&namebuf[0]));
    }
    inline unsigned char*   name()
    {
        if(namelen < 14) return namebuf;
        return *(unsigned char**)(&namebuf[0]);
    }
    inline const unsigned char*   name() const
    {
        if(namelen < 14) return namebuf;
        return *(const unsigned char**)(&namebuf[0]);
    }
    inline char* namec() { return (char*) name(); }
    inline const char*  namec() const { return (char*) name(); }
    
    inline bool isdir() const
    {
        return (unix_mode & S_IFMT) == S_IFDIR;
    }
    inline bool isreg() const
    {
        return (unix_mode & S_IFMT) == S_IFREG;
    }
    inline bool issymlink() const
    {
        return unix_type == DT_LNK;
    }
    inline bool isdotdot() const
    {
        return (namelen == 2) && (namebuf[0] == '.') && (namebuf[1] == '.'); // huh. can we have a regular file named ".."? Hope not.
    }
    inline bool ishidden() const
    {
        return !isdotdot() && (namec()[0] == '.' || (unix_flags & UF_HIDDEN));
    }
    inline bool hasextension() const
    {
        return extoffset != 0;
    }
    inline const char* extensionc() const
    {
        return namec() + extoffset;
    }
    inline bool cf_isselected() const
    {
        return cflags & DirectoryEntryCustomFlags::Selected;
    }
    inline void cf_setflag(unsigned int _flag)
    {
        cflags = cflags | _flag;
    }
    inline void cf_unsetflag(unsigned int _flag)
    {
        cflags = cflags & ~_flag;
    }
};


typedef bool (^FetchDirectoryListing_CancelChecker)(void);
// return true if algorithm need to stop, false if it's ok to go on

int FetchDirectoryListing(const char* _path,
                          std::deque<DirectoryEntryInformation> *_target,
                          FetchDirectoryListing_CancelChecker _checker // _check can be nil
                          );
// return 0 upon success, error code otherwise
// also return 0 upon cancelling, caller should check this condition

// releasing a following CF values is a caller's responsibility
//CFStringRef FileNameFromDirectoryEntryInformation(const DirectoryEntryInformation& _dirent);
//CFStringRef FileNameNoCopyFromDirectoryEntryInformation(const DirectoryEntryInformation& _dirent);


