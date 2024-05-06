// Copyright (C) 2013-2020 Michael G. Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <string>

namespace nc::base {

struct CommonPaths {
    // all returned paths will contain a trailing slash
    static const std::string &AppBundle() noexcept;
    static const std::string &Home() noexcept;
    static const std::string &Documents() noexcept;
    static const std::string &Desktop() noexcept;
    static const std::string &Downloads() noexcept;
    static const std::string &Applications() noexcept;
    static const std::string &Utilities() noexcept;
    static const std::string &Library() noexcept;
    static const std::string &Pictures() noexcept;
    static const std::string &Music() noexcept;
    static const std::string &Movies() noexcept;
    static const std::string &Root() noexcept;
    static const std::string &AppTemporaryDirectory() noexcept;
    static const std::string &StartupCWD() noexcept;
};

} // namespace nc::base
