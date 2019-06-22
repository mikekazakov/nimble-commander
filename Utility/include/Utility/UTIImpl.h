// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "UTI.h"
#include <mutex>
#include <unordered_map>
#include <unordered_set>

namespace nc::utility {

class UTIDBImpl : public UTIDB
{
public:
    UTIDBImpl();
    ~UTIDBImpl();

    std::string UTIForExtension(const std::string &_extension) const override;

    bool IsDeclaredUTI(const std::string &_uti) const override;
    
    bool IsDynamicUTI(const std::string &_uti) const override;

    bool ConformsTo(const std::string &_uti, const std::string &_conforms_to ) const override;

private:
    mutable std::unordered_map<std::string, std::string> m_ExtensionToUTI;
    mutable std::mutex m_ExtensionToUTILock;
    
    mutable std::unordered_map<std::string, std::unordered_set<std::string>> m_ConformsTo;
    mutable std::mutex m_ConformsToLock;
};

}
