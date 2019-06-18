// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/UTIImpl.h>
#include <CoreServices/CoreServices.h>
#include <Habanero/CFPtr.h>
#include <Habanero/CFString.h>

namespace nc::utility {

using nc::base::CFPtr;

UTIDBImpl::UTIDBImpl() = default;

UTIDBImpl::~UTIDBImpl() = default;

std::string UTIDBImpl::UTIForExtension(const std::string& _extension) const
{
    std::lock_guard lock{m_ExtensionToUTILock};
    if (auto i = m_ExtensionToUTI.find(_extension); i != std::end(m_ExtensionToUTI))
        return i->second;

    std::string uti;
    const auto ext = CFPtr<CFStringRef>::adopt(CFStringCreateWithUTF8StdStringNoCopy(_extension));
    if (ext) {
        const auto cf_uti = CFPtr<CFStringRef>::adopt(UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, ext.get(), nullptr));
        if (cf_uti) {
            uti = CFStringGetUTF8StdString(cf_uti.get());
            m_ExtensionToUTI.emplace(_extension, uti);
        }
    }
    return uti;
}

} // namespace nc::utility
