// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFSDeclarations.h>
#include <sys/stat.h>

namespace nc::vfs {

static_assert(sizeof(Stat) == 120);
static_assert(sizeof(Stat::meaningT) == 2);

void Stat::FromSysStat(const struct stat &_from, Stat &_to)
{
    _to.dev = _from.st_dev;
    _to.rdev = _from.st_rdev;
    _to.inode = _from.st_ino;
    _to.mode = _from.st_mode;
    _to.nlink = _from.st_nlink;
    _to.uid = _from.st_uid;
    _to.gid = _from.st_gid;
    _to.size = _from.st_size;
    _to.blocks = _from.st_blocks;
    _to.blksize = _from.st_blksize;
    _to.flags = _from.st_flags;
    _to.atime = _from.st_atimespec;
    _to.mtime = _from.st_mtimespec;
    _to.ctime = _from.st_ctimespec;
    _to.btime = _from.st_birthtimespec;
    _to.meaning = AllMeaning();
}

void Stat::ToSysStat(const Stat &_from, struct stat &_to)
{
    memset(&_to, 0, sizeof(_to));
    _to.st_dev = _from.dev;
    _to.st_rdev = _from.rdev;
    _to.st_ino = _from.inode;
    _to.st_mode = _from.mode;
    _to.st_nlink = _from.nlink;
    _to.st_uid = _from.uid;
    _to.st_gid = _from.gid;
    _to.st_size = _from.size;
    _to.st_blocks = _from.blocks;
    _to.st_blksize = _from.blksize;
    _to.st_flags = _from.flags;
    _to.st_atimespec = _from.atime;
    _to.st_mtimespec = _from.mtime;
    _to.st_ctimespec = _from.ctime;
    _to.st_birthtimespec = _from.btime;
}

struct stat Stat::SysStat() const noexcept
{
    struct stat st;
    ToSysStat(*this, st);
    return st;
}

} // namespace nc::vfs
