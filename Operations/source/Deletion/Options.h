// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops {

enum class DeletionType : int8_t
{
    Permanent = 0,
    Trash = 1
};

struct DeletionOptions {
    DeletionOptions(DeletionType _type) noexcept;
    DeletionType type;
};

inline DeletionOptions::DeletionOptions(DeletionType _type) noexcept : type(_type)
{
}

} // namespace nc::ops
