// Copyright (C) 2015-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>

#include <Base/UnorderedUtil.h>
#include <Base/spinlock.h>

namespace nc::utility {

class ExtensionLowercaseComparison
{
public:
    static ExtensionLowercaseComparison &Instance() noexcept;

    /**
     * Will check if there's already a cached lowercase form of _extension.
     * If there's no - will convert to lowercase and the will compose it to FormC normalization
     * level. Will store result in cache and return. Will not cache extension with utf8 length more
     * than m_MaxLength
     */
    std::string ExtensionToLowercase(std::string_view _extension);

    /**
     * Will try to find _filename_ext normalized lowercase form in cache, if can't - will produce it
     * temporary. _compare_to_formc_lc is used directly without any tranformation, so it should be
     * normalized and lowercased already
     */
    bool Equal(std::string_view _filename_ext, std::string_view _compare_to_formc_lc);

private:
    enum {
        m_MaxLength = 16
    };
    using Storage =
        ankerl::unordered_dense::map<std::string, std::string, UnorderedStringHashEqual, UnorderedStringHashEqual>;

    Storage m_Data;
    nc::spinlock m_Lock;
};

class ExtensionsLowercaseList
{
public:
    ExtensionsLowercaseList(std::string_view _comma_separated_list);
    bool contains(std::string_view _extension) const noexcept;

private:
    using Storage = ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual>;
    Storage m_List;
};

} // namespace nc::utility
