// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops {

struct CopyingOptions {
    enum class ChecksumVerification : char {
        Never = 0,
        WhenMoves = 1,
        Always = 2
    };

    enum class ExistBehavior : char {
        Ask = 0,          // default
        SkipAll = 1,      // silently skips any copiyng file, if target exists
        OverwriteAll = 2, // overwrites existings target
        OverwriteOld = 3, // overwrites existings target only if date is less, skip otherwise
        AppendAll = 4,    // appends to target
        Stop = 5,         // abort entire operation
        KeepBoth = 6      // always use a different name to keep both items
    };

    enum class LockedItemBehavior : char {
        Ask,       // default - ask what to when failed to deled a locked item
        SkipAll,   // silently skips deleting locked items
        UnlockAll, // silently unlock an item it wasn't removed
        Stop,      // abort entire operation
    };

    bool docopy : 1 = true; // it it false then operation will do renaming/moving
    bool preserve_symlinks : 1 = true;
    bool copy_xattrs : 1 = true;
    bool copy_file_times : 1 = true;
    bool copy_unix_flags : 1 = true;
    bool copy_unix_owners : 1 = true;
    bool disable_system_caches : 1 = false;
    ChecksumVerification verification = ChecksumVerification::Never;
    ExistBehavior exist_behavior = ExistBehavior::Ask;
    LockedItemBehavior locked_items_behaviour = LockedItemBehavior::Ask;
};

} // namespace nc::ops
