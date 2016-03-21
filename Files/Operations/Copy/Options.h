#pragma once

#include "../../ActivationManager.h"

struct FileCopyOperationOptions
{
    enum class ChecksumVerification
    {
        Never       = 0,
        WhenMoves   = 1,
        Always      = 2
    };
    
    bool docopy = true;      // it it false then operation will do renaming/moving
    bool preserve_symlinks = true;
    bool copy_xattrs = true;
    bool copy_file_times = true;
    bool copy_unix_flags = true;
    bool copy_unix_owners = true;
    bool force_overwrite = false;
//    ChecksumVerification verification = configuration::version >= configuration::Version::Pro ? ChecksumVerification::WhenMoves : ChecksumVerification::Never;
    ChecksumVerification verification = ActivationManager::Instance().HasCopyVerification() ? ChecksumVerification::WhenMoves : ChecksumVerification::Never;
};
