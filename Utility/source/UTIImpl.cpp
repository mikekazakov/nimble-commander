// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/UTIImpl.h>
#include <CoreServices/CoreServices.h>
#include <Habanero/CFPtr.h>
#include <Habanero/CFString.h>

namespace nc::utility {

using nc::base::CFPtr;

UTIDBImpl::UTIDBImpl() = default;

UTIDBImpl::~UTIDBImpl() = default;

std::string UTIDBImpl::UTIForExtension(const std::string &_extension) const
{
    std::lock_guard lock{m_ExtensionToUTILock};
    if( auto i = m_ExtensionToUTI.find(_extension); i != std::end(m_ExtensionToUTI) )
        return i->second;

    std::string uti;
    const auto ext = CFPtr<CFStringRef>::adopt(CFStringCreateWithUTF8StdStringNoCopy(_extension));
    if( ext ) {
        const auto cf_uti = CFPtr<CFStringRef>::adopt(UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, ext.get(), nullptr));
        if( cf_uti ) {
            uti = CFStringGetUTF8StdString(cf_uti.get());
            m_ExtensionToUTI.emplace(_extension, uti);
        }
    }
    return uti;
}

bool UTIDBImpl::IsDeclaredUTI(const std::string &_uti) const
{
    const auto ext = CFPtr<CFStringRef>::adopt(CFStringCreateWithUTF8StdStringNoCopy(_uti));
    if( ext ) {
        return UTTypeIsDeclared(ext.get());
    }
    return false;
}

bool UTIDBImpl::IsDynamicUTI(const std::string &_uti) const
{
    constexpr std::string_view prefix = "dyn.a";
    return std::string_view{_uti}.starts_with(prefix);
}

static void
TraverseConformingUTIs(const std::string &_uti,
                       robin_hood::unordered_flat_set<std::string,
                                                      RHTransparentStringHashEqual,
                                                      RHTransparentStringHashEqual> &_target)
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
    else if( CFGetTypeID(conforms_to) == CFArrayGetTypeID() ) {
        const CFArrayRef array = static_cast<CFArrayRef>(conforms_to);
        const auto number = CFArrayGetCount(array);
        for( auto i = 0; i < number; ++i ) {
            const auto object = CFArrayGetValueAtIndex(array, i);
            if( object != nullptr && CFGetTypeID(object) == CFStringGetTypeID() ) {
                const auto conforming_cf_string = static_cast<CFStringRef>(object);
                const auto conforming_std_string = CFStringGetUTF8StdString(conforming_cf_string);
                if( _target.contains(conforming_std_string) == false ) {
                    _target.emplace(conforming_std_string);
                    TraverseConformingUTIs(conforming_std_string, _target);
                }
            }
        }
    }
    else if( CFGetTypeID(conforms_to) == CFStringGetTypeID() ) {
        const auto conforming_cf_string = static_cast<CFStringRef>(conforms_to);
        const auto conforming_std_string = CFStringGetUTF8StdString(conforming_cf_string);
        if( _target.contains(conforming_std_string) == false ) {
            _target.emplace(conforming_std_string);
            TraverseConformingUTIs(conforming_std_string, _target);
        }
    }
}

bool UTIDBImpl::ConformsTo(const std::string &_uti, const std::string &_conforms_to) const
{
    std::lock_guard lock{m_ConformsToLock};
    if( const auto it = m_ConformsTo.find(_uti); it != m_ConformsTo.end() ) {
        const auto &conforming = it->second;
        return conforming.contains(_conforms_to);
    }
    robin_hood::
        unordered_flat_set<std::string, RHTransparentStringHashEqual, RHTransparentStringHashEqual>
            conforming_utis;
    TraverseConformingUTIs(_uti, conforming_utis);
    const bool does_conform = conforming_utis.contains(_conforms_to);
    m_ConformsTo[_uti] = std::move(conforming_utis);
    return does_conform;
}

} // namespace nc::utility
