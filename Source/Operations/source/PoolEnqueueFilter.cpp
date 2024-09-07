// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PoolEnqueueFilter.h"
#include "Operation.h"
#include "AttrsChanging/AttrsChanging.h"
#include "BatchRenaming/BatchRenaming.h"
#include "Compression/Compression.h"
#include "Copying/Copying.h"
#include "Deletion/Deletion.h"
#include "DirectoryCreation/DirectoryCreation.h"
#include "Linkage/Linkage.h"
#include <Base/UnorderedUtil.h>
#include <mutex>

namespace nc::ops {

void PoolEnqueueFilter::Set(std::string_view _id, bool _enable) noexcept
{
    const auto type = IDtoType(_id);
    if( type == nullptr )
        return;
    auto lock = std::lock_guard{m_Mutex};
    m_Enabled[std::type_index(*type)] = _enable;
}

bool PoolEnqueueFilter::ShouldEnqueue(const Operation &_operation) const noexcept
{
    const std::type_info &operation_type = typeid(_operation);
    auto lock = std::lock_guard{m_Mutex};
    auto it = m_Enabled.find(std::type_index(operation_type));
    if( it == m_Enabled.end() )
        return true;
    return it->second;
}

void PoolEnqueueFilter::Reset() noexcept
{
    auto lock = std::lock_guard{m_Mutex};
    m_Enabled.clear();
}

const std::type_info *PoolEnqueueFilter::IDtoType(std::string_view _id) noexcept
{
    [[clang::no_destroy]] static const auto mapping = [] {
        ankerl::unordered_dense::
            map<std::string, const std::type_info *, UnorderedStringHashEqual, UnorderedStringHashEqual>
                m;
        m.emplace("attrs_change", &typeid(AttrsChanging));
        m.emplace("batch_rename", &typeid(BatchRenaming));
        m.emplace("compress", &typeid(Compression));
        m.emplace("copy", &typeid(Copying));
        m.emplace("delete", &typeid(Deletion));
        m.emplace("mkdir", &typeid(DirectoryCreation));
        m.emplace("link", &typeid(Linkage));
        return m;
    }();
    if( auto it = mapping.find(_id); it != mapping.end() )
        return it->second;
    return nullptr;
}

std::string_view PoolEnqueueFilter::TypetoID(const std::type_info &_type) noexcept
{
    [[clang::no_destroy]] static const auto mapping = [] {
        ankerl::unordered_dense::map<std::type_index, std::string> m;
        m.emplace(typeid(AttrsChanging), "attrs_change");
        m.emplace(typeid(BatchRenaming), "batch_rename");
        m.emplace(typeid(Compression), "compress");
        m.emplace(typeid(Copying), "copy");
        m.emplace(typeid(Deletion), "delete");
        m.emplace(typeid(DirectoryCreation), "mkdir");
        m.emplace(typeid(Linkage), "link");
        return m;
    }();
    if( auto it = mapping.find(std::type_index(_type)); it != mapping.end() )
        return it->second;
    return {};
}

} // namespace nc::ops
