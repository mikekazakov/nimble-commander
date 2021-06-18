// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "UTI.h"
#include <mutex>
#include <Habanero/RobinHoodUtil.h>

namespace nc::utility {

class UTIDBImpl : public UTIDB
{
public:
    UTIDBImpl();
    ~UTIDBImpl();

    std::string UTIForExtension(const std::string &_extension) const override;

    bool IsDeclaredUTI(const std::string &_uti) const override;

    bool IsDynamicUTI(const std::string &_uti) const override;

    bool ConformsTo(const std::string &_uti, const std::string &_conforms_to) const override;

private:
    mutable robin_hood::unordered_flat_map<std::string,
                                           std::string,
                                           RHTransparentStringHashEqual,
                                           RHTransparentStringHashEqual>
        m_ExtensionToUTI;
    mutable std::mutex m_ExtensionToUTILock;

    mutable robin_hood::unordered_flat_map<
        std::string,
        robin_hood::unordered_flat_set<std::string,
                                       RHTransparentStringHashEqual,
                                       RHTransparentStringHashEqual>,
        RHTransparentStringHashEqual,
        RHTransparentStringHashEqual>
        m_ConformsTo;
    mutable std::mutex m_ConformsToLock;
};

} // namespace nc::utility
