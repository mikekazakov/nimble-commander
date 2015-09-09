//
//  VFSFlexibleListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "VFSFlexibleListing.h"
#include "VFSHost.h"

static bool BasicDirectoryCheck(const string& _str)
{
    if( _str.empty() )
        return false;
    if( _str.back() != '/' )
        return false;
    return true;
}

static void Validate(const VFSFlexibleListingInput& _source)
{
    if( _source.hosts.mode() == variable_container<>::type::sparse )
        throw logic_error("VFSFlexibleListingInput validation failed: hosts can't be sparse");
    
    for( auto i = 0u, e = _source.hosts.size(); i != e; ++i )
        if( _source.hosts[i] == nullptr )
            throw logic_error("VFSFlexibleListingInput validation failed: host can't be nullptr");
    
    if( _source.directories.mode() == variable_container<>::type::sparse )
        throw logic_error("VFSFlexibleListingInput validation failed: directories can't be sparse");

    for( auto i = 0u, e = _source.directories.size(); i != e; ++i )
        if( !BasicDirectoryCheck( _source.directories[i] ) )
            throw logic_error("VFSFlexibleListingInput validation failed: invalid directory");
    
    for( auto &s: _source.filenames )
        if( s.empty() )
            throw logic_error("VFSFlexibleListingInput validation failed: filename can't be empty");
    
    if( _source.display_filenames.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: dispay_filenames can't be common");

    if( _source.sizes.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: sizes can't be common");

    if( _source.inodes.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: inodes can't be common");

    if( _source.symlinks.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: symlinks can't be common");
    
    unsigned items_no = (unsigned)_source.filenames.size();
    if(_source.hosts.mode() == variable_container<>::type::dense &&
       _source.hosts.size() != items_no )
        throw logic_error("VFSFlexibleListingInput validation failed: hosts amount is inconsistent");
    
    if(_source.directories.mode() == variable_container<>::type::dense &&
       _source.directories.size() != items_no)
        throw logic_error("VFSFlexibleListingInput validation failed: directories amount is inconsistent");
    
    if(_source.unix_modes.size() != items_no)
        throw logic_error("VFSFlexibleListingInput validation failed: unix_modes amount is inconsistent");
    
    if(_source.unix_types.size() != items_no)
        throw logic_error("VFSFlexibleListingInput validation failed: unix_types amount is inconsistent");
        
    
}

shared_ptr<VFSFlexibleListing> VFSFlexibleListing::Build(VFSFlexibleListingInput &&_input)
{
    Validate( _input ); // will throw an exception on error

    auto l = Alloc();
    l->m_Hosts = move(_input.hosts);
    l->m_Directories = move(_input.directories);
    l->m_Filenames = move(_input.filenames);
    l->m_DisplayFilenames = move(_input.display_filenames);
    l->BuildFilenames();
    
    l->m_Sizes = move(_input.sizes);
    l->m_Inodes = move(_input.inodes);
    l->m_ATimes = move(_input.atimes);
    l->m_BTimes = move(_input.btimes);
    l->m_CTimes = move(_input.ctimes);
    l->m_MTimes = move(_input.mtimes);
    l->m_UnixModes = move(_input.unix_modes);
    l->m_UnixTypes = move(_input.unix_types);
    l->m_UIDS = move(_input.uids);
    l->m_GIDS = move(_input.gids);
    l->m_UnixFlags = move(_input.unix_flags);
    l->m_Symlinks = move(_input.symlinks);
    l->m_CreationTime = time(0);
    
    return l;
}

shared_ptr<VFSFlexibleListing> VFSFlexibleListing::EmptyListing()
{
    static shared_ptr<VFSFlexibleListing> empty;
    once_flag once;
    call_once(once, []{
        empty = Alloc();
        empty->m_ItemsCount = 0;
        empty->m_Hosts.insert(0, VFSHost::DummyHost());
        empty->m_Directories.insert(0, "/");
    });
    return empty;
}

shared_ptr<VFSFlexibleListing> VFSFlexibleListing::Alloc()
{
    struct make_shared_enabler: public VFSFlexibleListing {};
    return make_shared<make_shared_enabler>();
}

VFSFlexibleListing::VFSFlexibleListing()
{
}

static CFString UTF8WithFallback(const string &_s)
{
    CFString s( _s );
    if( !s )
        s = CFString( _s, kCFStringEncodingMacRoman );
    return s;
}

void VFSFlexibleListing::BuildFilenames()
{
    size_t i = 0, e = m_Filenames.size();
    m_ItemsCount = (unsigned)e;
    
    m_FilenamesCF.resize( e );
    m_ExtensionOffsets.resize( e );
    
//    variable_container<CFString>    m_DisplayFilenamesCF;
    m_DisplayFilenamesCF = variable_container<CFString>(variable_container<>::type::sparse);
    
    for(; i != e; ++i ) {
        auto &current = m_Filenames[i];

        // build Cocoa strings for filenames.
        // if filename is badly broken and UTF8 is invalid - treat it like MacRoman encoding
        m_FilenamesCF[i] = UTF8WithFallback(current);
        
        if( m_DisplayFilenames.has((unsigned)i) )
            m_DisplayFilenamesCF.insert((unsigned)i,
                                        UTF8WithFallback(m_DisplayFilenames[(unsigned)i]) );
        
        // parse extension if any
        // here we skip possible cases like
        // filename. and .filename
        // in such cases we think there's no extension at all
        uint16_t offset = 0;
        auto dot_it = current.find_last_of('.');
        if( dot_it != string::npos &&
            dot_it != 0 &&
            dot_it != current.size()-1 )
            offset = dot_it;
        m_ExtensionOffsets[i] = offset;
        
        
    
    }
}

#define __CHECK_BOUNDS( a ) \
    if( (a) >= m_ItemsCount ) \
        throw out_of_range(string(__PRETTY_FUNCTION__) + ": index out of range");

bool VFSFlexibleListing::HasExtension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    
    return m_ExtensionOffsets[_ind] != 0;
}

uint16_t VFSFlexibleListing::ExtensionOffset(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind];
}

const char *VFSFlexibleListing::Extension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind].c_str() + m_ExtensionOffsets[_ind];
}

const string& VFSFlexibleListing::Filename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind];
}

CFStringRef VFSFlexibleListing::FilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return *m_FilenamesCF[_ind];
}

const VFSHostPtr& VFSFlexibleListing::Host(unsigned _ind) const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    else {
        __CHECK_BOUNDS(_ind);
        return m_Hosts[_ind];
    }
}

const string& VFSFlexibleListing::Directory(unsigned _ind) const
{
    if( HasCommonDirectory() ) {
        return m_Directories[0];
    }
    else {
        __CHECK_BOUNDS(_ind);
        return m_Directories[_ind];
    }
}

bool VFSFlexibleListing::HasCommonHost() const
{
    return m_Hosts.mode() == variable_container<>::type::common;
}

bool VFSFlexibleListing::HasCommonDirectory() const
{
    return m_Directories.mode() == variable_container<>::type::common;
}

bool VFSFlexibleListing::HasSize(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind);
}

uint64_t VFSFlexibleListing::Size(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind) ? m_Sizes[_ind] : 0;
}

bool VFSFlexibleListing::HasInode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind);
}

uint64_t VFSFlexibleListing::Inode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind) ? m_Sizes[_ind] : 0;
}

bool VFSFlexibleListing::HasATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind);
}

time_t VFSFlexibleListing::ATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind) ? m_ATimes[_ind] : m_CreationTime;
}

bool VFSFlexibleListing::HasMTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind);
}

time_t VFSFlexibleListing::MTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind) ? m_MTimes[_ind] : m_CreationTime;
}

bool VFSFlexibleListing::HasCTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind);
}

time_t VFSFlexibleListing::CTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind) ? m_CTimes[_ind] : m_CreationTime;
}

bool VFSFlexibleListing::HasBTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind);
}

time_t VFSFlexibleListing::BTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind) ? m_BTimes[_ind] : m_CreationTime;
}

mode_t VFSFlexibleListing::UnixMode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixModes[_ind];
}

uint8_t VFSFlexibleListing::UnixType(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind];
}

bool VFSFlexibleListing::HasUID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind);
}

uid_t VFSFlexibleListing::UID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind) ? m_UIDS[_ind] : 0;
}

bool VFSFlexibleListing::HasGID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind);
}

gid_t VFSFlexibleListing::GID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind) ? m_GIDS[_ind] : 0;
}

bool VFSFlexibleListing::HasUnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind);
}

uint32_t VFSFlexibleListing::UnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind) ? m_UnixFlags[_ind] : 0;
}

bool VFSFlexibleListing::HasSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind);
}

const string& VFSFlexibleListing::Symlink(unsigned _ind) const
{
    static const string st = "";
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind) ? m_Symlinks[_ind] : st;
}

bool VFSFlexibleListing::HasDisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind);
}

const string& VFSFlexibleListing::DisplayFilename(unsigned _ind) const
{
    static const string st = "";
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind) ? m_DisplayFilenames[_ind] : st;
}

CFStringRef VFSFlexibleListing::DisplayFilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenamesCF.has(_ind) ? *m_DisplayFilenamesCF[_ind] : FilenameCF(_ind);
}

bool VFSFlexibleListing::IsDotDot(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    auto &s = m_Filenames[_ind];
    return s.length() == 2 && s[0]=='.' && s[1] == '.';
}

bool VFSFlexibleListing::IsDir(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & S_IFMT) == S_IFDIR;
}

bool VFSFlexibleListing::IsReg(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & S_IFMT) == S_IFREG;
}

bool VFSFlexibleListing::IsHidden(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (Filename(_ind)[0] == '.' || (UnixFlags(_ind) & UF_HIDDEN)) && !IsDotDot(_ind);
}

VFSFlexibleListingItem VFSFlexibleListing::Item(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return VFSFlexibleListingItem(shared_from_this(), _ind);
}

VFSFlexibleListing::iterator VFSFlexibleListing::begin() const
{
    iterator it;
    it.i = VFSFlexibleListingItem(shared_from_this(), 0);
    return it;
}

VFSFlexibleListing::iterator VFSFlexibleListing::end() const
{
    iterator it;
    it.i = VFSFlexibleListingItem(shared_from_this(), m_ItemsCount);
    return it;
}

//auto aa = []{
//    VFSFlexibleListingInput inp;
//    inp.directories[0] = "/";
//    inp.filenames.emplace_back("filename.txt");
//    
//    auto l = VFSFlexibleListing::Build(move(inp));
//    
//    l->Filename(0);
//    l->Filename(10);
//    
//    
//    
//    
//    
//    return 0;
//}();
