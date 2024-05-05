// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExtensionsWhitelist.h"
#include <Utility/UTI.h>
#include <Base/RobinHoodUtil.h>

#include <vector>
#include <mutex>

namespace nc::vfsicon {

class ExtensionsWhitelistImpl : public ExtensionsWhitelist
{
public:
    ExtensionsWhitelistImpl(const nc::utility::UTIDB &_uti_db, const std::vector<std::string> &_allowed_utis);
    ~ExtensionsWhitelistImpl();
    bool AllowExtension(const std::string &_extension) const override;

private:
    using WhitelistStorage =
        robin_hood::unordered_flat_map<std::string, bool, RHTransparentStringHashEqual, RHTransparentStringHashEqual>;

    const nc::utility::UTIDB &m_UTIDB;
    std::vector<std::string> m_Allowed_UTIs;

    mutable std::mutex m_WhitelistLock;
    mutable WhitelistStorage m_Whitelist;
};

} // namespace nc::vfsicon
