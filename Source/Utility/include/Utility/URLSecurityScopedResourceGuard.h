// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <vector>

namespace nc::utility {

class URLSecurityScopedResourceGuard
{
public:
    URLSecurityScopedResourceGuard(NSArray<NSURL *> *_urls);
    URLSecurityScopedResourceGuard(const URLSecurityScopedResourceGuard &) = delete;
    URLSecurityScopedResourceGuard(URLSecurityScopedResourceGuard &&) noexcept;
    ~URLSecurityScopedResourceGuard();
    URLSecurityScopedResourceGuard &operator=(const URLSecurityScopedResourceGuard &) = delete;
    URLSecurityScopedResourceGuard &operator=(URLSecurityScopedResourceGuard &&) noexcept;

private:
    std::vector<NSURL *> m_URLs;
};

} // namespace nc::utility
