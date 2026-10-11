// Copyright (C) 2019-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/UTIImpl.h>
#include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

namespace nc::utility {

std::string UTIDBImpl::UTIForExtension(std::string_view _extension) const
{
    const std::lock_guard lock{m_ExtensionToUTILock};
    if( const auto i = m_ExtensionToUTI.find(_extension); i != std::end(m_ExtensionToUTI) )
        return i->second;

    std::string uti;
    NSString *const ext = [[NSString alloc] initWithBytes:_extension.data()
                                                   length:_extension.size()
                                                 encoding:NSUTF8StringEncoding];
    if( ext != nil ) {
        UTType *const uttype = [UTType typeWithTag:ext tagClass:UTTagClassFilenameExtension conformingToType:nil];
        if( uttype != nil ) {
            uti = uttype.identifier.UTF8String;
        }
    }
    m_ExtensionToUTI.emplace(_extension, uti);
    return uti;
}

bool UTIDBImpl::IsDeclaredUTI(std::string_view _uti) const
{
    if( IsDynamicUTI(_uti) ) {
        return false; // dynamic UTIs are never declared
    }

    const std::lock_guard lock{m_DeclaredLock};
    if( const auto it = m_DeclaredUTIs.find(_uti); it != m_DeclaredUTIs.end() ) {
        return it->second;
    }

    NSString *const identifier = [[NSString alloc] initWithBytes:_uti.data()
                                                          length:_uti.size()
                                                        encoding:NSUTF8StringEncoding];
    const bool declared = (identifier != nil) && [UTType typeWithIdentifier:identifier].isDeclared;
    m_DeclaredUTIs.emplace(_uti, declared);
    return declared;
}

bool UTIDBImpl::IsDynamicUTI(std::string_view _uti) const
{
    constexpr std::string_view prefix = "dyn.a";
    return _uti.empty() || _uti.starts_with(prefix);
}

static ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual>
BuildConformingUTIs(std::string_view _uti)
{
    NSString *const identifier = [[NSString alloc] initWithBytes:_uti.data()
                                                          length:_uti.size()
                                                        encoding:NSUTF8StringEncoding];
    if( identifier == nil )
        return {};
    UTType *const uttype = [UTType typeWithIdentifier:identifier];
    if( uttype == nil )
        return {};

    ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual> set;

    for( UTType *supertype in uttype.supertypes ) {
        set.emplace(supertype.identifier.UTF8String);
    }
    return set;
}

bool UTIDBImpl::ConformsTo(std::string_view _uti, std::string_view _conforms_to) const
{
    const std::lock_guard lock{m_ConformsToLock};
    if( const auto it = m_ConformsTo.find(_uti); it != m_ConformsTo.end() ) {
        const auto &conforming = it->second;
        return conforming.contains(_conforms_to);
    }

    ankerl::unordered_dense::set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual> set =
        BuildConformingUTIs(_uti);

    const bool does_conform = set.contains(_conforms_to);
    m_ConformsTo[_uti] = std::move(set);

    return does_conform;
}

} // namespace nc::utility
