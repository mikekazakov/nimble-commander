// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>

namespace nc::ops {
    
class DirectoryPathAutoCompetion
{
public:
    virtual ~DirectoryPathAutoCompetion() = default;
    virtual std::vector<std::string> PossibleCompletions( const std::string &_path ) = 0;
    virtual std::string Complete( const std::string &_path, const std::string &_completion ) = 0;
};    
    
class DirectoryPathAutoCompletionImpl : public DirectoryPathAutoCompetion
{
public:
    DirectoryPathAutoCompletionImpl( VFSHostPtr _vfs );
    std::vector<std::string> PossibleCompletions( const std::string &_path ) override;
    std::string Complete( const std::string &_path, const std::string &_completion ) override;
    
private:
    std::string ExtractDirectory( const std::string &_path ) const;
    std::string ExtractFilename( const std::string &_path ) const;
    VFSListingPtr ListingForDir(const std::string& _path);
    static std::vector<unsigned> ListDirsWithPrefix(const VFSListing& _listing,
                                                    const std::string& _prefix);    
    
    VFSHostPtr m_VFS;
    VFSListingPtr m_LastListing;              
};
    
}

@interface NCFilenameTextStorage : NSTextStorage
@end

@interface NCFilenameTextCell : NSTextFieldCell
@end

// Either set this object as a delegate or forward @selector(complete:) into this delegate
@interface NCFilepathAutoCompletionDelegate : NSObject<NSTextFieldDelegate>

@property (nonatomic) std::shared_ptr<nc::ops::DirectoryPathAutoCompetion> completion;
@property (nonatomic) bool isNativeVFS;

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)commandSelector;

@end
