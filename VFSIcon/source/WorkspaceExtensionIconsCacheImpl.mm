// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/WorkspaceExtensionIconsCacheImpl.h>
#include <Cocoa/Cocoa.h>
#include <Utility/StringExtras.h>

namespace nc::vfsicon {

WorkspaceExtensionIconsCacheImpl::
    WorkspaceExtensionIconsCacheImpl(const nc::utility::UTIDB &_uti_db):
    m_UTIDB(_uti_db)
{
    m_GenericFolderIcon = [NSImage imageNamed:NSImageNameFolder];
    m_GenericFileIcon = [NSWorkspace.sharedWorkspace iconForFileType:
        NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
}
    
WorkspaceExtensionIconsCacheImpl::~WorkspaceExtensionIconsCacheImpl()
{        
}

NSImage *WorkspaceExtensionIconsCacheImpl::
    CachedIconForExtension( const std::string& _extension ) const
{
    return Find_Locked(_extension);
}

NSImage *WorkspaceExtensionIconsCacheImpl::Find_Locked( const std::string &_extension ) const
{
    if( _extension.empty() )
        return nil;
    
    LOCK_GUARD(m_Lock) {
        if( const auto i = m_Icons.find( _extension ); i != end(m_Icons) )
            return i->second;
    }
    return nil;
}

void WorkspaceExtensionIconsCacheImpl::
    Commit_Locked( const std::string &_extension, NSImage *_image)
{
    LOCK_GUARD(m_Lock) {
        m_Icons.emplace(_extension, _image);
    }
}

NSImage *WorkspaceExtensionIconsCacheImpl::IconForExtension( const std::string& _extension )
{
    if( _extension.empty() )
        return nil;
    
    LOCK_GUARD(m_Lock) {
        if( auto i = m_Icons.find( _extension );  i != end(m_Icons) )
            return i->second;
    }
    
    const auto uti = m_UTIDB.UTIForExtension(_extension);
    if( not m_UTIDB.IsDynamicUTI(uti) ) {
        const auto image = [NSWorkspace.sharedWorkspace
            iconForFileType:[NSString stringWithUTF8StdString:uti]];
        Commit_Locked( _extension, image );
        return image;
    }
    else {
        Commit_Locked( _extension, nil );
        return nil;
    }
}

NSImage *WorkspaceExtensionIconsCacheImpl::GenericFileIcon() const
{
    return m_GenericFileIcon;
}

NSImage *WorkspaceExtensionIconsCacheImpl::GenericFolderIcon() const
{
    return m_GenericFolderIcon;
}

}

