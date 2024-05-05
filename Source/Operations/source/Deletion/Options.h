// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops {

enum class DeletionType : char {
    Permanent = 0,
    Trash = 1
};

struct DeletionOptions {
    enum class LockedItemBehavior : char {
        Ask,       // default - ask what to when failed to deled a locked item
        SkipAll,   // silently skips deleting locked items
        UnlockAll, // silently unlock an item it wasn't removed
        Stop,      // abort entire operation
    };

    DeletionOptions() = default;
    DeletionOptions(DeletionType _type) noexcept;

    DeletionType type = DeletionType::Permanent;
    LockedItemBehavior locked_items_behaviour = LockedItemBehavior::Ask;
};

inline DeletionOptions::DeletionOptions(DeletionType _type) noexcept : type(_type)
{
}

} // namespace nc::ops
