// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSFile.h"

NSData *VFSFile::ReadFileToNSData()
{
    const std::expected<std::vector<uint8_t>, nc::Error> d = ReadFile();
    return d ? [NSData dataWithBytes:d->data() length:d->size()] : nil;
}
