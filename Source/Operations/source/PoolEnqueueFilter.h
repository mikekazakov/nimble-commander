// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <typeindex>
#include <ankerl/unordered_dense.h>
#include <Base/spinlock.h>

namespace nc::ops {

class Operation;

// RTTI-based filter that checks a run-time type of an operation and says if it has to be enqueued
// in a pool once a concurrency limit is reached. The default response is 'true'
// It provided a conveniency human-readable operation IDs in a string form:
// nc::ops::AttrsChanging - "attrs_change"
// nc::ops::BatchRenaming - "batch_rename"
// nc::ops::Compression - "compress"
// nc::ops::Copying - "copy"
// nc::ops::Deletion - "delete"
// nc::ops::DirectoryCreation - "mkdir"
// nc::ops::Linkage - "link"
// This class API-level thread-safe
class PoolEnqueueFilter
{
public:
    // Returns true if _operation should obey concorrency limits and be enqued if they are reached
    bool ShouldEnqueue(const Operation &_operation) const noexcept;

    // Specifies the behaviour for a particular operation type
    void Set(std::string_view _id, bool _enable) noexcept;

    // Removes all rules
    void Reset() noexcept;

    // Return a pointer to a valid type_info object that accords to the identifier.
    // If there's no such identifier the function returns nullptr
    static const std::type_info *IDtoType(std::string_view _id) noexcept;

    // Returns an identifier of a run-time operation type.
    // If this type is not recongnised the functions returns an empty string.
    static std::string_view TypetoID(const std::type_info &_type) noexcept;

private:
    ankerl::unordered_dense::map<std::type_index, bool> m_Enabled;
    mutable spinlock m_Mutex;
};

} // namespace nc::ops
