//
//  VFSListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "../include/VFS/VFSListing.h"
#include "../include/VFS/VFSHost.h"
#include "VFSListingInput.h"

static_assert( is_move_constructible<VFSListingItem>::value, "" );
static_assert( is_move_constructible<VFSListing::iterator>::value, "" );

static bool BasicDirectoryCheck(const string& _str)
{
    if( _str.empty() )
        return false;
    if( _str.back() != '/' )
        return false;
    return true;
}

static void Validate(const VFSListingInput& _source)
{
    if( _source.hosts.mode() == variable_container<>::type::sparse )
        throw logic_error("VFSListingInput validation failed: hosts can't be sparse");
    
    for( auto i = 0u, e = _source.hosts.size(); i != e; ++i )
        if( _source.hosts[i] == nullptr )
            throw logic_error("VFSListingInput validation failed: host can't be nullptr");
    
    if( _source.directories.mode() == variable_container<>::type::sparse )
        throw logic_error("VFSListingInput validation failed: directories can't be sparse");

    for( auto i = 0u, e = _source.directories.size(); i != e; ++i )
        if( !BasicDirectoryCheck( _source.directories[i] ) )
            throw logic_error("VFSListingInput validation failed: invalid directory");
    
    for( auto &s: _source.filenames )
        if( s.empty() )
            throw logic_error("VFSListingInput validation failed: filename can't be empty");
    
    if( _source.display_filenames.mode() == variable_container<>::type::common )
        throw logic_error("VFSListingInput validation failed: dispay_filenames can't be common");

    if( _source.sizes.mode() == variable_container<>::type::common )
        throw logic_error("VFSListingInput validation failed: sizes can't be common");

    if( _source.inodes.mode() == variable_container<>::type::common )
        throw logic_error("VFSListingInput validation failed: inodes can't be common");

    if( _source.symlinks.mode() == variable_container<>::type::common )
        throw logic_error("VFSListingInput validation failed: symlinks can't be common");
    
    unsigned items_no = (unsigned)_source.filenames.size();
    if(_source.hosts.mode() == variable_container<>::type::dense &&
       _source.hosts.size() != items_no )
        throw logic_error("VFSListingInput validation failed: hosts amount is inconsistent");
    
    if(_source.directories.mode() == variable_container<>::type::dense &&
       _source.directories.size() != items_no)
        throw logic_error("VFSListingInput validation failed: directories amount is inconsistent");
    
    if(_source.unix_modes.size() != items_no)
        throw logic_error("VFSListingInput validation failed: unix_modes amount is inconsistent");
    
    if(_source.unix_types.size() != items_no)
        throw logic_error("VFSListingInput validation failed: unix_types amount is inconsistent");
        
    
}

static void Compress( VFSListingInput &_input )
{
    if( _input.sizes.mode() == variable_container<>::type::sparse && _input.sizes.is_contiguous() )         _input.sizes.compress_contiguous();
    if( _input.inodes.mode() == variable_container<>::type::sparse && _input.inodes.is_contiguous() )     	_input.inodes.compress_contiguous();
    if( _input.atimes.mode() == variable_container<>::type::sparse && _input.atimes.is_contiguous() )       _input.atimes.compress_contiguous();
    if( _input.mtimes.mode() == variable_container<>::type::sparse && _input.mtimes.is_contiguous() )       _input.mtimes.compress_contiguous();
    if( _input.ctimes.mode() == variable_container<>::type::sparse && _input.ctimes.is_contiguous() )       _input.ctimes.compress_contiguous();
    if( _input.btimes.mode() == variable_container<>::type::sparse && _input.btimes.is_contiguous() )       _input.btimes.compress_contiguous();
    if( _input.add_times.mode() == variable_container<>::type::sparse && _input.add_times.is_contiguous() ) _input.add_times.compress_contiguous();
    if( _input.uids.mode() == variable_container<>::type::sparse && _input.uids.is_contiguous() )           _input.uids.compress_contiguous();
    if( _input.gids.mode() == variable_container<>::type::sparse && _input.gids.is_contiguous() )           _input.gids.compress_contiguous();
    if( _input.unix_flags.mode() == variable_container<>::type::sparse && _input.unix_flags.is_contiguous() ) _input.unix_flags.compress_contiguous();

    // todo: ability to compress hosts into common? dense is an overkill here in most cases
    
}

shared_ptr<VFSListing> VFSListing::Build(VFSListingInput &&_input)
{
    Validate( _input ); // will throw an exception on error
    Compress( _input );
    
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
    l->m_AddTimes = move(_input.add_times);
    l->m_UnixModes = move(_input.unix_modes);
    l->m_UnixTypes = move(_input.unix_types);
    l->m_UIDS = move(_input.uids);
    l->m_GIDS = move(_input.gids);
    l->m_UnixFlags = move(_input.unix_flags);
    l->m_Symlinks = move(_input.symlinks);
    l->m_CreationTime = time(0);
    
    return l;
}

VFSListingInput VFSListing::Compose(const vector<shared_ptr<VFSListing>> &_listings, const vector< vector<unsigned> > &_items_indeces)
{
    if( _listings.size() != _items_indeces.size() )
        throw invalid_argument("VFSListing::Compose input containers has different sizes");
    
    VFSListingInput result;
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
                throw invalid_argument("VFSListing::Compose: invalid index");
            
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
    
    return result;
}

VFSListingPtr VFSListing::ProduceUpdatedTemporaryPanelListing( const VFSListing& _original, VFSCancelChecker _cancel_checker )
{
    VFSListingInput result;
    unsigned count = 0;
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
    
    for(unsigned i = 0, e = _original.Count(); i != e; ++i) {
        if( _cancel_checker && _cancel_checker() )
            return  nullptr;
        
        char path[MAXPATHLEN];
        strcpy( path, _original.Directory(i).c_str() );
        strcat( path, _original.Filename(i).c_str() );
        
        VFSStat st;
        auto stat_flags = _original.IsSymlink(i) ? VFSFlags::F_NoFollow : 0;
        if( _original.Host(i)->Stat(path, st, stat_flags, _cancel_checker) == 0 ) {
            
            result.filenames.emplace_back ( _original.Filename(i) );
            result.unix_modes.emplace_back( _original.UnixMode(i) );
            result.unix_types.emplace_back( _original.UnixType(i) );
            result.hosts.insert      ( count, _original.Host(i) );
            result.directories.insert( count, _original.Directory(i) );
            
            if( st.meaning.size )   result.sizes.insert( count, st.size );
            if( st.meaning.inode )  result.inodes.insert( count, st.inode );
            if( st.meaning.atime )  result.atimes.insert( count, st.atime.tv_sec );
            if( st.meaning.btime )  result.btimes.insert( count, st.btime.tv_sec );
            if( st.meaning.ctime )  result.ctimes.insert( count, st.ctime.tv_sec );
            if( st.meaning.mtime )  result.mtimes.insert( count, st.mtime.tv_sec );
            if( st.meaning.uid )    result.uids.insert( count, st.uid );
            if( st.meaning.gid )    result.gids.insert( count, st.gid );
            if( st.meaning.flags )  result.unix_flags.insert( count, st.flags );
            
            // mb update symlink too?
            if( _original.HasSymlink(i) ) result.symlinks.insert( count, _original.Symlink(i) );
            if( _original.HasDisplayFilename(i) ) result.display_filenames.insert( count, _original.DisplayFilename(i) );
            
            count++;
        }
    }
    
    if( _cancel_checker && _cancel_checker() )
        return  nullptr;
    
    return Build( move(result) );
}

shared_ptr<VFSListing> VFSListing::EmptyListing()
{
    static shared_ptr<VFSListing> empty = []{
        auto l = Alloc();
        l->m_ItemsCount = 0;
        l->m_Hosts.insert(0, VFSHost::DummyHost());
        l->m_Directories.insert(0, "/");
        return l;
    }();
    return empty;
}

shared_ptr<VFSListing> VFSListing::Alloc()
{
    struct make_shared_enabler: public VFSListing {};
    return make_shared<make_shared_enabler>();
}

VFSListing::VFSListing()
{
}

static CFString UTF8WithFallback(const string &_s)
{
    CFString s( _s );
    if( !s )
        s = CFString( _s, kCFStringEncodingMacRoman );
    return s;
}

void VFSListing::BuildFilenames()
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

bool VFSListing::HasExtension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind] != 0;
}

uint16_t VFSListing::ExtensionOffset(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind];
}

const char *VFSListing::Extension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind].c_str() + m_ExtensionOffsets[_ind];
}

const string& VFSListing::Filename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind];
}

CFStringRef VFSListing::FilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return *m_FilenamesCF[_ind];
}

string VFSListing::Path(unsigned _ind) const
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

string VFSListing::FilenameWithoutExt(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    if( m_ExtensionOffsets[_ind] == 0 )
        return m_Filenames[_ind];
    return m_Filenames[_ind].substr(0, m_ExtensionOffsets[_ind]-1);
}

const VFSHostPtr& VFSListing::Host() const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    throw logic_error("VFSListing::Host() called for listing with no common host");
}

const VFSHostPtr& VFSListing::Host(unsigned _ind) const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    else {
        __CHECK_BOUNDS(_ind);
        return m_Hosts[_ind];
    }
}

const string& VFSListing::Directory() const
{
    if( HasCommonDirectory() )
        return m_Directories[0];
    throw logic_error("VFSListing::Directory() called for listing with no common directory");
}

const string& VFSListing::Directory(unsigned _ind) const
{
    if( HasCommonDirectory() ) {
        return m_Directories[0];
    }
    else {
        __CHECK_BOUNDS(_ind);
        return m_Directories[_ind];
    }
}

unsigned VFSListing::Count() const noexcept
{
    return m_ItemsCount;
};

bool VFSListing::Empty() const noexcept
{
    return m_ItemsCount == 0;
}

bool VFSListing::IsUniform() const noexcept
{
    return HasCommonHost() && HasCommonDirectory();
}

bool VFSListing::HasCommonHost() const noexcept
{
    return m_Hosts.mode() == variable_container<>::type::common;
}

bool VFSListing::HasCommonDirectory() const noexcept
{
    return m_Directories.mode() == variable_container<>::type::common;
}

bool VFSListing::HasSize(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind);
}

uint64_t VFSListing::Size(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind) ? m_Sizes[_ind] : 0;
}

bool VFSListing::HasInode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind);
}

uint64_t VFSListing::Inode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind) ? m_Inodes[_ind] : 0;
}

bool VFSListing::HasATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind);
}

time_t VFSListing::ATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind) ? m_ATimes[_ind] : m_CreationTime;
}

bool VFSListing::HasMTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind);
}

time_t VFSListing::MTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind) ? m_MTimes[_ind] : m_CreationTime;
}

bool VFSListing::HasCTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind);
}

time_t VFSListing::CTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind) ? m_CTimes[_ind] : m_CreationTime;
}

bool VFSListing::HasBTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind);
}

time_t VFSListing::BTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind) ? m_BTimes[_ind] : m_CreationTime;
}

bool VFSListing::HasAddTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_AddTimes.has(_ind);
}

time_t VFSListing::AddTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_AddTimes.has(_ind) ? m_AddTimes[_ind] : BTime(_ind);
}

mode_t VFSListing::UnixMode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixModes[_ind];
}

uint8_t VFSListing::UnixType(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind];
}

bool VFSListing::HasUID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind);
}

uid_t VFSListing::UID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind) ? m_UIDS[_ind] : 0;
}

bool VFSListing::HasGID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind);
}

gid_t VFSListing::GID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind) ? m_GIDS[_ind] : 0;
}

bool VFSListing::HasUnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind);
}

uint32_t VFSListing::UnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind) ? m_UnixFlags[_ind] : 0;
}

bool VFSListing::HasSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind);
}

const string& VFSListing::Symlink(unsigned _ind) const
{
    static const string st = "";
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind) ? m_Symlinks[_ind] : st;
}

bool VFSListing::HasDisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind);
}

const string& VFSListing::DisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind) ? m_DisplayFilenames[_ind] : Filename(_ind);
}

CFStringRef VFSListing::DisplayFilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenamesCF.has(_ind) ? *m_DisplayFilenamesCF[_ind] : FilenameCF(_ind);
}

bool VFSListing::IsDotDot(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    auto &s = m_Filenames[_ind];
    return s[0]=='.' && s[1] == '.' && s[2] == 0;
}

bool VFSListing::IsDir(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & S_IFMT) == S_IFDIR;
}

bool VFSListing::IsReg(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & S_IFMT) == S_IFREG;
}

bool VFSListing::IsSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind] == DT_LNK;
}

bool VFSListing::IsHidden(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (Filename(_ind)[0] == '.' || (UnixFlags(_ind) & UF_HIDDEN)) && !IsDotDot(_ind);
}

VFSListingItem VFSListing::Item(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return VFSListingItem(shared_from_this(), _ind);
}

VFSListing::iterator VFSListing::begin() const noexcept
{
    iterator it;
    it.i = VFSListingItem(shared_from_this(), 0);
    return it;
}

VFSListing::iterator VFSListing::end() const noexcept
{
    iterator it;
    it.i = VFSListingItem(shared_from_this(), m_ItemsCount);
    return it;
}

/**
 * VFSListingItem
 *///////
VFSListingItem::VFSListingItem() noexcept:
    I( numeric_limits<unsigned>::max() ),
    L( nullptr )
{
}

VFSListingItem::VFSListingItem(const shared_ptr<const VFSListing>& _listing, unsigned _ind) noexcept:
    I(_ind),
    L(_listing)
{
}

VFSListingItem::operator bool() const noexcept
{
    return (bool)L;
}

const shared_ptr<const VFSListing>& VFSListingItem::Listing() const noexcept
{
    return L;
}

unsigned VFSListingItem::Index() const noexcept
{
    return I;
}

string VFSListingItem::Path() const
{
    return L->Path(I);
}

const VFSHostPtr& VFSListingItem::Host() const
{
    return L->Host(I);
}

const string& VFSListingItem::Directory() const
{
    return L->Directory(I);
}

const string& VFSListingItem::Filename() const
{
    return L->Filename(I);
}

const char *VFSListingItem::Name() const
{
    return L->Filename(I).c_str();
}

size_t VFSListingItem::NameLen() const
{
    return L->Filename(I).length();
}

CFStringRef VFSListingItem::CFName() const
{
    return L->FilenameCF(I);
}

bool VFSListingItem::HasDisplayName() const
{
    return L->HasDisplayFilename(I);
}

const string& VFSListingItem::DisplayName() const
{
    return L->DisplayFilename(I);
}

CFStringRef VFSListingItem::CFDisplayName() const
{
    return L->DisplayFilenameCF(I);
}

bool VFSListingItem::HasExtension() const
{
    return L->HasExtension(I);
}

uint16_t VFSListingItem::ExtensionOffset() const
{
    return L->ExtensionOffset(I);
}

const char* VFSListingItem::Extension() const
{
    return L->Extension(I);
}

const char* VFSListingItem::ExtensionIfAny() const
{
    return HasExtension() ? Extension() : "";
}

string VFSListingItem::FilenameWithoutExt() const
{
    return L->FilenameWithoutExt(I);
}

mode_t VFSListingItem::UnixMode() const
{
    return L->UnixMode(I);
}

uint8_t VFSListingItem::UnixType() const
{
    return L->UnixType(I);
}

bool VFSListingItem::HasSize() const
{
    return L->HasSize(I);
}

uint64_t VFSListingItem::Size() const
{
    return L->Size(I);
}

bool VFSListingItem::HasInode() const
{
    return L->HasInode(I);
}

uint64_t VFSListingItem::Inode() const
{
    return L->Inode(I);
}

bool VFSListingItem::HasATime() const
{
    return L->HasATime(I);
}

time_t VFSListingItem::ATime() const
{
    return L->ATime(I);
}

bool VFSListingItem::HasMTime() const
{
    return L->HasMTime(I);
}

time_t VFSListingItem::MTime() const
{
    return L->MTime(I);
}

bool VFSListingItem::HasCTime() const
{
    return L->HasCTime(I);
}

time_t VFSListingItem::CTime() const
{
    return L->CTime(I);
}

bool VFSListingItem::HasBTime() const
{
    return L->HasBTime(I);
}

time_t VFSListingItem::BTime() const
{
    return L->BTime(I);
}

bool VFSListingItem::HasAddTime() const
{
    return L->HasAddTime(I);
}

time_t VFSListingItem::AddTime() const
{
    return L->AddTime(I);
}

bool VFSListingItem::HasUnixFlags() const
{
    return L->HasUnixFlags(I);
}

uint32_t VFSListingItem::UnixFlags() const
{
    return L->UnixFlags(I);
}

bool VFSListingItem::HasUnixUID() const
{
    return L->HasUID(I);
}

uid_t VFSListingItem::UnixUID() const
{
    return L->UID(I);
}

bool VFSListingItem::HasUnixGID() const
{
    return L->HasGID(I);
}

gid_t VFSListingItem::UnixGID() const
{
    return L->GID(I);
}

bool VFSListingItem::HasSymlink() const
{
    return L->HasSymlink(I);
}

const char *VFSListingItem::Symlink() const
{
    return L->Symlink(I).c_str();
}

bool VFSListingItem::IsDir() const
{
    return L->IsDir(I);
}

bool VFSListingItem::IsReg() const
{
    return L->IsReg(I);
}

bool VFSListingItem::IsSymlink() const
{
    return L->IsSymlink(I);
}

bool VFSListingItem::IsDotDot() const
{
    return L->IsDotDot(I);
}

bool VFSListingItem::IsHidden() const
{
    return L->IsHidden(I);
}

bool VFSListingItem::operator ==(const VFSListingItem&_) const noexcept
{
    return I == _.I && L == _.L;
}

bool VFSListingItem::operator !=(const VFSListingItem&_) const noexcept
{
    return I != _.I || L != _.L;
}

VFSWeakListingItem::VFSWeakListingItem() noexcept
{
}

VFSWeakListingItem::VFSWeakListingItem(const VFSListingItem &_item) noexcept:
    L(_item.L),
    I(_item.I)
{
}

VFSWeakListingItem::VFSWeakListingItem(const VFSWeakListingItem &_item) noexcept:
    L(_item.L),
    I(_item.I)
{
}

VFSWeakListingItem::VFSWeakListingItem(VFSWeakListingItem &&_item) noexcept:
    L( move(_item.L) ),
    I( _item.I )
{
}

const VFSWeakListingItem& VFSWeakListingItem::operator=( const VFSListingItem &_item ) noexcept
{
    L = _item.L;
    I = _item.I;
    return *this;
}

const VFSWeakListingItem& VFSWeakListingItem::operator=( const VFSWeakListingItem &_item ) noexcept
{
    L = _item.L;
    I = _item.I;
    return *this;
}

const VFSWeakListingItem& VFSWeakListingItem::operator=( VFSWeakListingItem &&_item ) noexcept
{
    L = move(_item.L);
    I = _item.I;
    return *this;
}

VFSListingItem VFSWeakListingItem::Lock() const noexcept
{
    return { L.lock(), I };
}

bool VFSWeakListingItem::operator ==(const VFSWeakListingItem&_) const noexcept
{
    return I == _.I && !L.owner_before(_.L) && !_.L.owner_before(L);
}

bool VFSWeakListingItem::operator !=(const VFSWeakListingItem&_) const noexcept
{
    return !(*this == _);
}

bool VFSWeakListingItem::operator ==(const VFSListingItem&_) const noexcept
{
    return I == _.I && !L.owner_before(_.L) && !_.L.owner_before(L);
}

bool VFSWeakListingItem::operator !=(const VFSListingItem&_) const noexcept
{
    return !(*this == _);
}

bool operator==(const VFSListingItem&_l, const VFSWeakListingItem&_r) noexcept
{
    return _r == _l;
}

bool operator!=(const VFSListingItem&_l, const VFSWeakListingItem&_r) noexcept
{
    return !(_r == _l);
}

/**
 * VFSListing::iterator
 *///////
VFSListing::iterator &VFSListing::iterator::operator--() noexcept // prefix decrement
{
    i.I--;
    return *this;
}

VFSListing::iterator &VFSListing::iterator::operator++() noexcept // prefix increment
{
    i.I++;
    return *this;
}
VFSListing::iterator VFSListing::iterator::operator--(int) noexcept // posfix decrement
{
    auto p = *this;
    i.I--;
    return p;
}

VFSListing::iterator VFSListing::iterator::operator++(int) noexcept // posfix increment
{
    auto p = *this;
    i.I++;
    return p;
}
    
bool VFSListing::iterator::operator==(const iterator& _r) const noexcept
{
    return i.I == _r.i.I && i.L == _r.i.L;
}

bool VFSListing::iterator::operator!=(const iterator& _r) const noexcept
{
    return !(*this == _r);
}

const VFSListingItem& VFSListing::iterator::operator*() const noexcept
{
    return i;
}
