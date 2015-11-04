//
//  VFSFlexibleListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "VFSListing.h"
#include "VFSHost.h"

static_assert( is_move_constructible<VFSFlexibleListingItem>::value, "" );
static_assert( is_move_constructible<VFSFlexibleListing::iterator>::value, "" );

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

VFSFlexibleListingInput VFSFlexibleListing::Compose(const vector<shared_ptr<VFSFlexibleListing>> &_listings, const vector< vector<unsigned> > &_items_indeces)
{
    if( _listings.size() != _items_indeces.size() )
        throw invalid_argument("VFSFlexibleListing::Compose input containers has different sizes");
    
    VFSFlexibleListingInput result;
    result.hosts.reset( variable_container<>::type::dense );
    result.directories.reset( variable_container<>::type::dense );
    result.display_filenames.reset( variable_container<>::type::sparse );
    result.sizes.reset( variable_container<>::type::sparse );
    result.inodes.reset( variable_container<>::type::sparse );
    result.atimes.reset( variable_container<>::type::sparse );
    result.mtimes.reset( variable_container<>::type::sparse );
    result.ctimes.reset( variable_container<>::type::sparse );
    result.btimes.reset( variable_container<>::type::sparse );
    result.uids.reset( variable_container<>::type::sparse );
    result.gids.reset( variable_container<>::type::sparse );
    result.unix_flags.reset( variable_container<>::type::sparse );
    result.symlinks.reset( variable_container<>::type::sparse );
 
    unsigned count = 0;
    for( size_t l = 0, e = _listings.size(); l != e; ++l ) {
        auto &listing = *_listings[l];
        auto &indeces = _items_indeces[l];
        for(auto i: indeces) {
            if( i >= listing.Count() )
                throw invalid_argument("VFSFlexibleListing::Compose: invalid index");
            
            result.filenames.emplace_back ( listing.Filename(i) );
            result.unix_modes.emplace_back( listing.UnixMode(i) );
            result.unix_types.emplace_back( listing.UnixType(i) );
            result.hosts.insert      ( count, listing.Host(i) );
            result.directories.insert( count, listing.Directory(i) );
            if( listing.HasDisplayFilename(i) )
                result.display_filenames.insert( count, listing.DisplayFilename(i) );
            if( listing.HasSize(i) )
                result.sizes.insert( count, listing.Size(i) );
            if( listing.HasInode(i) )
                result.inodes.insert( count, listing.Inode(i) );
            if( listing.HasATime(i) )
                result.atimes.insert( count, listing.ATime(i) );
            if( listing.HasBTime(i) )
                result.btimes.insert( count, listing.BTime(i) );
            if( listing.HasCTime(i) )
                result.ctimes.insert( count, listing.CTime(i) );
            if( listing.HasMTime(i) )
                result.mtimes.insert( count, listing.MTime(i) );
            if( listing.HasUID(i) )
                result.uids.insert( count, listing.UID(i) );
            if( listing.HasGID(i) )
                result.gids.insert( count, listing.GID(i) );
            if( listing.HasUnixFlags(i) )
                result.unix_flags.insert( count, listing.UnixFlags(i) );
            if( listing.HasSymlink(i) )
                result.symlinks.insert( count, listing.Symlink(i) );
            
            count++;
        }
    }
    if( result.sizes.is_contiguous() )      result.sizes.compress_contiguous();
    if( result.inodes.is_contiguous() )     result.inodes.compress_contiguous();
    if( result.atimes.is_contiguous() )     result.atimes.compress_contiguous();
    if( result.mtimes.is_contiguous() )     result.mtimes.compress_contiguous();
    if( result.ctimes.is_contiguous() )     result.ctimes.compress_contiguous();
    if( result.btimes.is_contiguous() )     result.btimes.compress_contiguous();
    if( result.uids.is_contiguous() )       result.uids.compress_contiguous();
    if( result.gids.is_contiguous() )       result.gids.compress_contiguous();
    if( result.unix_flags.is_contiguous() ) result.unix_flags.compress_contiguous();
    
    return result;
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
            offset = dot_it+1;
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

string VFSFlexibleListing::Path(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    if( !IsDotDot(_ind) )
        return m_Directories[_ind] + m_Filenames[_ind];
    else {
        string p = m_Directories[_ind];
        if( p.length() > 1 )
            p.pop_back();
        return p;
    }
}

string VFSFlexibleListing::FilenameWithoutExt(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    if( m_ExtensionOffsets[_ind] == 0 )
        return m_Filenames[_ind];
    return m_Filenames[_ind].substr(0, m_ExtensionOffsets[_ind]-1);
}

const VFSHostPtr& VFSFlexibleListing::Host() const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    throw logic_error("VFSFlexibleListing::Host() called for listing with no common host");
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

const string& VFSFlexibleListing::Directory() const
{
    if( HasCommonDirectory() )
        return m_Directories[0];
    throw logic_error("VFSFlexibleListing::Directory() called for listing with no common directory");
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

bool VFSFlexibleListing::IsUniform() const
{
    return m_Hosts.mode() == variable_container<>::type::common &&
     m_Directories.mode() == variable_container<>::type::common;
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
    return s[0]=='.' && s[1] == '.' && s[2] == 0;
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

VFSFlexibleListing::iterator VFSFlexibleListing::begin() const noexcept
{
    iterator it;
    it.i = VFSFlexibleListingItem(shared_from_this(), 0);
    return it;
}

VFSFlexibleListing::iterator VFSFlexibleListing::end() const noexcept
{
    iterator it;
    it.i = VFSFlexibleListingItem(shared_from_this(), m_ItemsCount);
    return it;
}
