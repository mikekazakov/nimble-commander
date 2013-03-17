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

struct DirectoryEntryInformation // 96b long
{
    // #0
    unsigned char  namebuf[14];             // UTF-8, including null-term. if namelen >13 => (char**)&name[0] is a buffer from malloc for namelen+1 bytes
    // #14
    unsigned short namelen;                 // not-including null-term
    // #16
    unsigned long  ino;                     // 64b-long inode number
    // #24
    unsigned long  size;                    // file size. initial 0xFFFFFFFF for directories, other value means calculated directory size
    // #32
    time_t         atime;                   // time of last access
    // #40
    time_t         mtime;                   // time of last data modification
    // #48
    time_t         ctime;                   // time of last status change (data modification OR access changes, hardlink changes etc)
    // #56
    time_t         btime;                   // time of file creation(birth);
    // #64
    unsigned int   cflags;                  // custom flags. volatile - can be changed. up to 32 flags
    // #68
    CFStringRef    cf_name;                 // it's a string created with CFStringCreateWithBytesNoCopy, pointing at name()
    // #76
    signed short   extoffset;               // extension of a file if any. -1 if there's no extension, or position of a first char of an extention
    // #78
    mode_t         mode;                    // file type from stat
    // #80
    unsigned char  type;                    // file type from <sys/dirent.h> (from readdir)
    // #81
    unsigned char  ___padding[15];
    // #96

    inline void destroy()
    {
        CFRelease(cf_name);
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
//        return type == DT_DIR;
        return (mode & S_IFMT) == S_IFDIR;
    }
    inline bool isreg() const
    {
//        return type == DT_REG;
        return (mode & S_IFMT) == S_IFREG;        
    }
    inline bool isdotdot() const
    {
        return (namelen == 2) && (namebuf[0] == '.') && (namebuf[1] == '.'); // huh. can we have a regular file named ".."? Hope not.
    }
    inline bool ishidden() const
    {
        return !isdotdot() && namec()[0] == '.';
    }
    inline bool hasextension() const
    {
        return extoffset != -1;
    }
    inline const char* extensionc() const // undefined behaviour if called for file without extension
    {
        assert(extoffset != -1);
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

int FetchDirectoryListing(const char* _path, std::deque<DirectoryEntryInformation> *_target);

// releasing a following CF values is a caller's responsibility
CFStringRef FileNameFromDirectoryEntryInformation(const DirectoryEntryInformation& _dirent);
CFStringRef FileNameNoCopyFromDirectoryEntryInformation(const DirectoryEntryInformation& _dirent);


