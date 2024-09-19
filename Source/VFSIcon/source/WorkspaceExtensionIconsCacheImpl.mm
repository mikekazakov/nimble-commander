// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/WorkspaceExtensionIconsCacheImpl.h>
#include <VFSIcon/Log.h>
#include <Cocoa/Cocoa.h>
#include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

namespace nc::vfsicon {

WorkspaceExtensionIconsCacheImpl::WorkspaceExtensionIconsCacheImpl(const nc::utility::UTIDB &_uti_db) : m_UTIDB(_uti_db)
{
    m_GenericFolderIcon = [NSImage imageNamed:NSImageNameFolder];
    m_GenericFileIcon = [NSWorkspace.sharedWorkspace iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
}

WorkspaceExtensionIconsCacheImpl::~WorkspaceExtensionIconsCacheImpl() = default;

NSImage *WorkspaceExtensionIconsCacheImpl::CachedIconForExtension(const std::string &_extension) const
{
    return Find_Locked(_extension);
}

NSImage *WorkspaceExtensionIconsCacheImpl::Find_Locked(const std::string &_extension) const
{
    if( _extension.empty() )
        return nil;

    const auto lock = std::lock_guard{m_Lock};
    if( const auto i = m_Icons.find(_extension); i != end(m_Icons) )
        return i->second;
    return nil;
}

void WorkspaceExtensionIconsCacheImpl::Commit_Locked(const std::string &_extension, NSImage *_image)
{
    const auto lock = std::lock_guard{m_Lock};
    m_Icons.emplace(_extension, _image);
}

NSImage *WorkspaceExtensionIconsCacheImpl::IconForExtension(const std::string &_extension)
{
    Log::Trace("IconForExtension() called for '{}'", _extension);

    if( _extension.empty() )
        return nil;

    {
        const auto lock = std::lock_guard{m_Lock};
        if( auto i = m_Icons.find(_extension); i != m_Icons.end() ) {
            Log::Trace("IconForExtension() found a cached icon for '{}'", _extension);
            return i->second;
        }
    }

    const auto uti = m_UTIDB.UTIForExtension(_extension);
    Log::Info("IconForExtension() uti for '{}' is '{}'", _extension, uti);
    if( not m_UTIDB.IsDynamicUTI(uti) ) {
        Log::Info("IconForExtension() getting an icon for filetype: '{}'", _extension);
        NSImage *image = nil;
        if( @available(macOS 11.0, *) ) {
            Log::Debug("IconForExtension() polling [NSWorkspace iconForContentType:'{}']", uti);
            UTType *const uttype = [UTType typeWithIdentifier:[NSString stringWithUTF8StdString:uti]];
            image = [NSWorkspace.sharedWorkspace iconForContentType:uttype];
        }
        else {
            Log::Debug("IconForExtension() polling [NSWorkspace iconForFileType:'{}']", uti);
            image = [NSWorkspace.sharedWorkspace iconForFileType:[NSString stringWithUTF8StdString:uti]];
        }
        Commit_Locked(_extension, image);
        return image;
    }
    else {
        Log::Info("IconForExtension() '{}' has dynamic uti, placing nil", _extension);
        Commit_Locked(_extension, nil);
        return nil;
    }
}

NSImage *WorkspaceExtensionIconsCacheImpl::GenericFileIcon() const
{
    Log::Trace("GenericFileIcon() called");
    return m_GenericFileIcon;
}

NSImage *WorkspaceExtensionIconsCacheImpl::GenericFolderIcon() const
{
    Log::Trace("GenericFolderIcon() called");
    return m_GenericFolderIcon;
}

} // namespace nc::vfsicon
