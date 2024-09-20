// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/URLSecurityScopedResourceGuard.h>
#include <Utility/Log.h>

namespace nc::utility {

URLSecurityScopedResourceGuard::URLSecurityScopedResourceGuard(NSArray<NSURL *> *_urls)
{
    for( NSURL *url in _urls ) {
        if( [url startAccessingSecurityScopedResource] ) {
            Log::Trace("Started accessing a security scoped resource: {}", url.fileSystemRepresentation);
            m_URLs.emplace_back(url);
        }
        else {
            // not complaining in the log since it's valid for an URL to not contain a security
            // payload
        }
    }
}

URLSecurityScopedResourceGuard::URLSecurityScopedResourceGuard(URLSecurityScopedResourceGuard &&) noexcept = default;

URLSecurityScopedResourceGuard::~URLSecurityScopedResourceGuard()
{
    for( NSURL *const &url : m_URLs ) {
        [url stopAccessingSecurityScopedResource];
        Log::Trace("Stopped accessing a security scoped resource: {}", url.fileSystemRepresentation);
    }
}

URLSecurityScopedResourceGuard &
URLSecurityScopedResourceGuard::operator=(URLSecurityScopedResourceGuard &&) noexcept = default;

} // namespace nc::utility
