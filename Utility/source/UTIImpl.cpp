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

bool UTIDBImpl::IsDeclaredUTI(const std::string& _uti) const
{
    const auto ext = CFPtr<CFStringRef>::adopt(CFStringCreateWithUTF8StdStringNoCopy(_uti));
    if (ext) {
        return UTTypeIsDeclared(ext.get());
    }
    return false;
}

bool UTIDBImpl::IsDynamicUTI(const std::string& _uti) const
{
    constexpr std::string_view prefix = "dyn.a";
    return std::string_view{_uti}.starts_with(prefix);
}

static void TraverseConformingUTIs(const std::string &_uti,
    std::unordered_set<std::string> &_target )
{
    const auto uti = CFPtr<CFStringRef>::adopt(CFStringCreateWithUTF8StdString(_uti));
    if( !uti )
        return;
        
    const auto declaration = CFPtr<CFDictionaryRef>::adopt(UTTypeCopyDeclaration(uti.get()));
    if( !declaration )
        return;
  
    const CFTypeRef conforms_to = CFDictionaryGetValue(declaration.get(), kUTTypeConformsToKey);
    if( conforms_to == nullptr )
        return;
    else if (CFGetTypeID(conforms_to) == CFArrayGetTypeID()) {
        const CFArrayRef array = (CFArrayRef)conforms_to;
        const auto number = CFArrayGetCount(array);
        for (auto i = 0; i < number; ++i) {
            const auto object = CFArrayGetValueAtIndex(array, i);
            if (object != nullptr && CFGetTypeID(object) == CFStringGetTypeID()) {
                const auto conforming_cf_string = (CFStringRef)object;
                const auto conforming_std_string = CFStringGetUTF8StdString(conforming_cf_string);
                if( _target.count(conforming_std_string) == 0 ) {
                    _target.emplace(conforming_std_string);
                    TraverseConformingUTIs(conforming_std_string, _target);
                } 
            }
        }
    }
    else if( CFGetTypeID(conforms_to) == CFStringGetTypeID()) {
        const auto conforming_cf_string = (CFStringRef)conforms_to;
        const auto conforming_std_string = CFStringGetUTF8StdString(conforming_cf_string);
        if( _target.count(conforming_std_string) == 0 ) {
            _target.emplace(conforming_std_string);
            TraverseConformingUTIs(conforming_std_string, _target);
        }
    }
}

bool UTIDBImpl::ConformsTo(const std::string &_uti, const std::string &_conforms_to ) const
{
    std::lock_guard lock{m_ConformsToLock};
    if( const auto it = m_ConformsTo.find(_uti); it != m_ConformsTo.end() ) {
        const auto &conforming = it->second;
        return conforming.count(_conforms_to) != 0;
    }
    std::unordered_set<std::string> conforming_utis;
    TraverseConformingUTIs(_uti, conforming_utis);
    m_ConformsTo[_uti] = conforming_utis;
    return conforming_utis.count(_conforms_to) != 0; 
}

} // namespace nc::utility
