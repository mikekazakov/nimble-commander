// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "UTI.h"
#include <mutex>
#include <Base/UnorderedUtil.h>

namespace nc::utility {

class UTIDBImpl : public UTIDB
{
public:
    std::string UTIForExtension(std::string_view _extension) const override;

    bool IsDeclaredUTI(std::string_view _uti) const override;

    bool IsDynamicUTI(std::string_view _uti) const override;

    bool ConformsTo(std::string_view _uti, std::string_view _conforms_to) const override;

private:
    mutable ankerl::unordered_dense::map<std::string, std::string, UnorderedStringHashEqual, UnorderedStringHashEqual>
        m_ExtensionToUTI;
    mutable std::mutex m_ExtensionToUTILock;

    mutable ankerl::unordered_dense::map<
        std::string,
        ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual>,
        UnorderedStringHashEqual,
        UnorderedStringHashEqual>
        m_ConformsTo;
    mutable std::mutex m_ConformsToLock;
};

} // namespace nc::utility
