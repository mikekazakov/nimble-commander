// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/UTIImpl.h>
#include <CoreServices/CoreServices.h>
#include <Base/CFPtr.h>
#include <Base/CFString.h>
#include <fmt/core.h>

namespace nc::utility {

using nc::base::CFPtr;

std::string UTIDBImpl::UTIForExtension(std::string_view _extension) const
{
    const std::lock_guard lock{m_ExtensionToUTILock};
    if( auto i = m_ExtensionToUTI.find(_extension); i != std::end(m_ExtensionToUTI) )
        return i->second;

    std::string uti;
    if( const auto ext = CFPtr<CFStringRef>::adopt(base::CFStringCreateWithUTF8StringNoCopy(_extension)) ) {
        const auto cf_uti = CFPtr<CFStringRef>::adopt(
            UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext.get(), nullptr));
        if( cf_uti ) {
            uti = base::CFStringGetUTF8StdString(cf_uti.get());
            m_ExtensionToUTI.emplace(_extension, uti);
        }
    }
    return uti;
}

bool UTIDBImpl::IsDeclaredUTI(std::string_view _uti) const
{
    if( const auto ext = CFPtr<CFStringRef>::adopt(base::CFStringCreateWithUTF8StringNoCopy(_uti)) ) {
        return UTTypeIsDeclared(ext.get());
    }
    return false;
}

bool UTIDBImpl::IsDynamicUTI(std::string_view _uti) const
{
    constexpr std::string_view prefix = "dyn.a";
    return _uti.starts_with(prefix);
}

static void TraverseConformingUTIs(
    std::string_view _uti,
    ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual> &_target)
{
    const auto uti = CFPtr<CFStringRef>::adopt(base::CFStringCreateWithUTF8StringNoCopy(_uti));
    if( !uti )
        return;

    const auto declaration = CFPtr<CFDictionaryRef>::adopt(UTTypeCopyDeclaration(uti.get()));
    if( !declaration )
        return;

    const CFTypeRef conforms_to = CFDictionaryGetValue(declaration.get(), kUTTypeConformsToKey);
    if( conforms_to == nullptr )
        return;
    else if( CFGetTypeID(conforms_to) == CFArrayGetTypeID() ) {
        const CFArrayRef array = static_cast<CFArrayRef>(conforms_to);
        const auto number = CFArrayGetCount(array);
        for( auto i = 0; i < number; ++i ) {
            const auto object = CFArrayGetValueAtIndex(array, i);
            if( object != nullptr && CFGetTypeID(object) == CFStringGetTypeID() ) {
                const auto conforming_cf_string = static_cast<CFStringRef>(object);
                const auto conforming_std_string = base::CFStringGetUTF8StdString(conforming_cf_string);
                if( !_target.contains(conforming_std_string) ) {
                    _target.emplace(conforming_std_string);
                    TraverseConformingUTIs(conforming_std_string, _target);
                }
            }
        }
    }
    else if( CFGetTypeID(conforms_to) == CFStringGetTypeID() ) {
        const auto conforming_cf_string = static_cast<CFStringRef>(conforms_to);
        const auto conforming_std_string = base::CFStringGetUTF8StdString(conforming_cf_string);
        if( !_target.contains(conforming_std_string) ) {
            _target.emplace(conforming_std_string);
            TraverseConformingUTIs(conforming_std_string, _target);
        }
    }
}

bool UTIDBImpl::ConformsTo(std::string_view _uti, std::string_view _conforms_to) const
{
    const std::lock_guard lock{m_ConformsToLock};
    if( const auto it = m_ConformsTo.find(_uti); it != m_ConformsTo.end() ) {
        const auto &conforming = it->second;
        return conforming.contains(_conforms_to);
    }
    ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual> conforming_utis;
    TraverseConformingUTIs(_uti, conforming_utis);

    const bool does_conform = conforming_utis.contains(_conforms_to);
    m_ConformsTo[_uti] = std::move(conforming_utis);

    return does_conform;
}

} // namespace nc::utility
