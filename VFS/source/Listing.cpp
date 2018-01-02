// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Listing.h"
#include "../include/VFS/Host.h"
#include "ListingInput.h"

namespace nc::vfs {

static_assert( is_move_constructible<ListingItem>::value, "" );
static_assert( is_move_constructible<Listing::iterator>::value, "" );

static bool BasicDirectoryCheck(const string& _str)
{
    if( _str.empty() )
        return false;
    if( _str.back() != '/' )
        return false;
    return true;
}

static void Validate(const ListingInput& _source)
{
    int items_no = (int)_source.filenames.size();

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
    
    if( _source.display_filenames.mode() == variable_container<>::type::common && items_no > 1 )
        throw logic_error("VFSListingInput validation failed: dispay_filenames can't be common");

    if( _source.sizes.mode() == variable_container<>::type::common && items_no > 1 )
        throw logic_error("VFSListingInput validation failed: sizes can't be common");

    if( _source.inodes.mode() == variable_container<>::type::common && items_no > 1 )
        throw logic_error("VFSListingInput validation failed: inodes can't be common");

    if( _source.symlinks.mode() == variable_container<>::type::common && items_no > 1 )
        throw logic_error("VFSListingInput validation failed: symlinks can't be common");
    
    if(_source.hosts.mode() == variable_container<>::type::dense &&
       (int)_source.hosts.size() != items_no )
        throw logic_error("VFSListingInput validation failed: hosts amount is inconsistent");
    
    if(_source.directories.mode() == variable_container<>::type::dense &&
       (int)_source.directories.size() != items_no)
        throw logic_error("VFSListingInput validation failed: directories amount is inconsistent");
    
    if((int)_source.unix_modes.size() != items_no)
        throw logic_error("VFSListingInput validation failed: unix_modes amount is inconsistent");
    
    if((int)_source.unix_types.size() != items_no)
        throw logic_error("VFSListingInput validation failed: unix_types amount is inconsistent");
        
    
}

template <class C>
static void CompressIntoContiguous( C &_cont )
{
    if( _cont.mode() == variable_container<>::type::sparse && _cont.is_contiguous() )
        _cont.compress_contiguous();
}
    
static void Compress( ListingInput &_input )
{
    CompressIntoContiguous( _input.sizes );
    CompressIntoContiguous( _input.inodes );
    CompressIntoContiguous( _input.atimes );
    CompressIntoContiguous( _input.mtimes );
    CompressIntoContiguous( _input.ctimes );
    CompressIntoContiguous( _input.btimes );
    CompressIntoContiguous( _input.add_times );
    CompressIntoContiguous( _input.uids );
    CompressIntoContiguous( _input.gids );
    CompressIntoContiguous( _input.unix_flags );

    // todo: ability to compress hosts into common? dense is an overkill here in most cases
    
}

shared_ptr<Listing> Listing::Build(ListingInput &&_input)
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

ListingInput Listing::Compose(const vector<shared_ptr<Listing>> &_listings)
{
    ListingInput result;
    result.hosts.reset( variable_container<>::type::dense );
    result.directories.reset( variable_container<>::type::dense );
    result.display_filenames.reset( variable_container<>::type::sparse );
    result.sizes.reset( variable_container<>::type::sparse );
    result.inodes.reset( variable_container<>::type::sparse );
    result.atimes.reset( variable_container<>::type::sparse );
    result.mtimes.reset( variable_container<>::type::sparse );
    result.ctimes.reset( variable_container<>::type::sparse );
    result.btimes.reset( variable_container<>::type::sparse );
    result.add_times.reset( variable_container<>::type::sparse );
    result.uids.reset( variable_container<>::type::sparse );
    result.gids.reset( variable_container<>::type::sparse );
    result.unix_flags.reset( variable_container<>::type::sparse );
    result.symlinks.reset( variable_container<>::type::sparse );
 
    unsigned count = 0;
    for( auto &listing_ptr: _listings ) {
        auto &listing = *listing_ptr;
        for( int i = 0, e = (int)listing.Count(); i != e; ++i ) {
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
            if( listing.HasAddTime(i) )
                result.add_times.insert( count, listing.AddTime(i) );
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

ListingInput Listing::Compose(const vector<shared_ptr<Listing>> &_listings, const vector< vector<unsigned> > &_items_indeces)
{
    if( _listings.size() != _items_indeces.size() )
        throw invalid_argument("VFSListing::Compose input containers has different sizes");
    
    ListingInput result;
    result.hosts.reset( variable_container<>::type::dense );
    result.directories.reset( variable_container<>::type::dense );
    result.display_filenames.reset( variable_container<>::type::sparse );
    result.sizes.reset( variable_container<>::type::sparse );
    result.inodes.reset( variable_container<>::type::sparse );
    result.atimes.reset( variable_container<>::type::sparse );
    result.mtimes.reset( variable_container<>::type::sparse );
    result.ctimes.reset( variable_container<>::type::sparse );
    result.btimes.reset( variable_container<>::type::sparse );
    result.add_times.reset( variable_container<>::type::sparse );
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
            if( listing.HasAddTime(i) )
                result.add_times.insert( count, listing.AddTime(i) );                
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

VFSListingPtr Listing::ProduceUpdatedTemporaryPanelListing( const Listing& _original, VFSCancelChecker _cancel_checker )
{
    ListingInput result;
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

const shared_ptr<Listing> &Listing::EmptyListing() noexcept
{
    static const auto empty = []{
        auto l = Alloc();
        l->m_ItemsCount = 0;
        l->m_Hosts.insert(0, Host::DummyHost());
        l->m_Directories.insert(0, "/");
        return l;
    }();
    return empty;
}

shared_ptr<Listing> Listing::Alloc()
{
    struct make_shared_enabler: public Listing {};
    return make_shared<make_shared_enabler>();
}

Listing::Listing()
{
}

Listing::~Listing()
{
}

static CFString UTF8WithFallback(const string &_s)
{
    CFString s( _s );
    if( !s )
        s = CFString( _s, kCFStringEncodingMacRoman );
    return s;
}

void Listing::BuildFilenames()
{
    size_t i = 0, e = m_Filenames.size();
    m_ItemsCount = (unsigned)e;
    
    m_FilenamesCF.resize( e );
    m_ExtensionOffsets.resize( e );
    
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
            offset = uint16_t(dot_it+1);
        m_ExtensionOffsets[i] = offset;
    }
}

#define __CHECK_BOUNDS( a ) \
    if( (a) >= m_ItemsCount ) \
        throw out_of_range(string(__PRETTY_FUNCTION__) + ": index out of range");

bool Listing::HasExtension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind] != 0;
}

uint16_t Listing::ExtensionOffset(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind];
}

const char *Listing::Extension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind].c_str() + m_ExtensionOffsets[_ind];
}

const string& Listing::Filename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind];
}

CFStringRef Listing::FilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return *m_FilenamesCF[_ind];
}

string Listing::Path(unsigned _ind) const
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

string Listing::FilenameWithoutExt(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    if( m_ExtensionOffsets[_ind] == 0 )
        return m_Filenames[_ind];
    return m_Filenames[_ind].substr(0, m_ExtensionOffsets[_ind]-1);
}

const VFSHostPtr& Listing::Host() const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    throw logic_error("Listing::Host() called for listing with no common host");
}

const VFSHostPtr& Listing::Host(unsigned _ind) const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    else {
        __CHECK_BOUNDS(_ind);
        return m_Hosts[_ind];
    }
}

const string& Listing::Directory() const
{
    if( HasCommonDirectory() )
        return m_Directories[0];
    throw logic_error("Listing::Directory() called for listing with no common directory");
}

const string& Listing::Directory(unsigned _ind) const
{
    if( HasCommonDirectory() ) {
        return m_Directories[0];
    }
    else {
        __CHECK_BOUNDS(_ind);
        return m_Directories[_ind];
    }
}

unsigned Listing::Count() const noexcept
{
    return m_ItemsCount;
};

bool Listing::Empty() const noexcept
{
    return m_ItemsCount == 0;
}

bool Listing::IsUniform() const noexcept
{
    return HasCommonHost() && HasCommonDirectory();
}

bool Listing::HasCommonHost() const noexcept
{
    return m_Hosts.mode() == variable_container<>::type::common;
}

bool Listing::HasCommonDirectory() const noexcept
{
    return m_Directories.mode() == variable_container<>::type::common;
}

bool Listing::HasSize(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind);
}

uint64_t Listing::Size(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind) ? m_Sizes[_ind] : 0;
}

bool Listing::HasInode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind);
}

uint64_t Listing::Inode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind) ? m_Inodes[_ind] : 0;
}

bool Listing::HasATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind);
}

time_t Listing::ATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind) ? m_ATimes[_ind] : m_CreationTime;
}

bool Listing::HasMTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind);
}

time_t Listing::MTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind) ? m_MTimes[_ind] : m_CreationTime;
}

bool Listing::HasCTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind);
}

time_t Listing::CTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind) ? m_CTimes[_ind] : m_CreationTime;
}

bool Listing::HasBTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind);
}

time_t Listing::BTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind) ? m_BTimes[_ind] : m_CreationTime;
}

bool Listing::HasAddTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_AddTimes.has(_ind);
}

time_t Listing::AddTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_AddTimes.has(_ind) ? m_AddTimes[_ind] : BTime(_ind);
}

mode_t Listing::UnixMode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixModes[_ind];
}

uint8_t Listing::UnixType(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind];
}

bool Listing::HasUID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind);
}

uid_t Listing::UID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind) ? m_UIDS[_ind] : 0;
}

bool Listing::HasGID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind);
}

gid_t Listing::GID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind) ? m_GIDS[_ind] : 0;
}

bool Listing::HasUnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind);
}

uint32_t Listing::UnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind) ? m_UnixFlags[_ind] : 0;
}

bool Listing::HasSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind);
}

const string& Listing::Symlink(unsigned _ind) const
{
    static const string st = "";
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind) ? m_Symlinks[_ind] : st;
}

bool Listing::HasDisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind);
}

const string& Listing::DisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind) ? m_DisplayFilenames[_ind] : Filename(_ind);
}

CFStringRef Listing::DisplayFilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenamesCF.has(_ind) ? *m_DisplayFilenamesCF[_ind] : FilenameCF(_ind);
}

bool Listing::IsDotDot(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    auto &s = m_Filenames[_ind];
    return s[0]=='.' && s[1] == '.' && s[2] == 0;
}

bool Listing::IsDir(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & S_IFMT) == S_IFDIR;
}

bool Listing::IsReg(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & S_IFMT) == S_IFREG;
}

bool Listing::IsSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind] == DT_LNK;
}

bool Listing::IsHidden(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (Filename(_ind)[0] == '.' || (UnixFlags(_ind) & UF_HIDDEN)) && !IsDotDot(_ind);
}

ListingItem Listing::Item(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return ListingItem(shared_from_this(), _ind);
}

Listing::iterator Listing::begin() const noexcept
{
    iterator it;
    it.i = ListingItem(shared_from_this(), 0);
    return it;
}

Listing::iterator Listing::end() const noexcept
{
    iterator it;
    it.i = ListingItem(shared_from_this(), m_ItemsCount);
    return it;
}

/**
 * VFSListingItem
 *///////
ListingItem::ListingItem() noexcept:
    I( numeric_limits<unsigned>::max() ),
    L( nullptr )
{
}

ListingItem::ListingItem(const shared_ptr<const class Listing>& _listing, unsigned _ind) noexcept:
    I(_ind),
    L(_listing)
{
}

ListingItem::operator bool() const noexcept
{
    return (bool)L;
}

const shared_ptr<const Listing>& ListingItem::Listing() const noexcept
{
    return L;
}

unsigned ListingItem::Index() const noexcept
{
    return I;
}

string ListingItem::Path() const
{
    return L->Path(I);
}

const VFSHostPtr& ListingItem::Host() const
{
    return L->Host(I);
}

const string& ListingItem::Directory() const
{
    return L->Directory(I);
}

const string& ListingItem::Filename() const
{
    return L->Filename(I);
}

const char *ListingItem::FilenameC() const
{
    return L->Filename(I).c_str();
}

size_t ListingItem::FilenameLen() const
{
    return L->Filename(I).length();
}

CFStringRef ListingItem::FilenameCF() const
{
    return L->FilenameCF(I);
}

bool ListingItem::HasDisplayName() const
{
    return L->HasDisplayFilename(I);
}

const string& ListingItem::DisplayName() const
{
    return L->DisplayFilename(I);
}

CFStringRef ListingItem::DisplayNameCF() const
{
    return L->DisplayFilenameCF(I);
}

bool ListingItem::HasExtension() const
{
    return L->HasExtension(I);
}

uint16_t ListingItem::ExtensionOffset() const
{
    return L->ExtensionOffset(I);
}

const char* ListingItem::Extension() const
{
    return L->Extension(I);
}

const char* ListingItem::ExtensionIfAny() const
{
    return HasExtension() ? Extension() : "";
}

string ListingItem::FilenameWithoutExt() const
{
    return L->FilenameWithoutExt(I);
}

mode_t ListingItem::UnixMode() const
{
    return L->UnixMode(I);
}

uint8_t ListingItem::UnixType() const
{
    return L->UnixType(I);
}

bool ListingItem::HasSize() const
{
    return L->HasSize(I);
}

uint64_t ListingItem::Size() const
{
    return L->Size(I);
}

bool ListingItem::HasInode() const
{
    return L->HasInode(I);
}

uint64_t ListingItem::Inode() const
{
    return L->Inode(I);
}

bool ListingItem::HasATime() const
{
    return L->HasATime(I);
}

time_t ListingItem::ATime() const
{
    return L->ATime(I);
}

bool ListingItem::HasMTime() const
{
    return L->HasMTime(I);
}

time_t ListingItem::MTime() const
{
    return L->MTime(I);
}

bool ListingItem::HasCTime() const
{
    return L->HasCTime(I);
}

time_t ListingItem::CTime() const
{
    return L->CTime(I);
}

bool ListingItem::HasBTime() const
{
    return L->HasBTime(I);
}

time_t ListingItem::BTime() const
{
    return L->BTime(I);
}

bool ListingItem::HasAddTime() const
{
    return L->HasAddTime(I);
}

time_t ListingItem::AddTime() const
{
    return L->AddTime(I);
}

bool ListingItem::HasUnixFlags() const
{
    return L->HasUnixFlags(I);
}

uint32_t ListingItem::UnixFlags() const
{
    return L->UnixFlags(I);
}

bool ListingItem::HasUnixUID() const
{
    return L->HasUID(I);
}

uid_t ListingItem::UnixUID() const
{
    return L->UID(I);
}

bool ListingItem::HasUnixGID() const
{
    return L->HasGID(I);
}

gid_t ListingItem::UnixGID() const
{
    return L->GID(I);
}

bool ListingItem::HasSymlink() const
{
    return L->HasSymlink(I);
}

const char *ListingItem::Symlink() const
{
    return L->Symlink(I).c_str();
}

bool ListingItem::IsDir() const
{
    return L->IsDir(I);
}

bool ListingItem::IsReg() const
{
    return L->IsReg(I);
}

bool ListingItem::IsSymlink() const
{
    return L->IsSymlink(I);
}

bool ListingItem::IsDotDot() const
{
    return L->IsDotDot(I);
}

bool ListingItem::IsHidden() const
{
    return L->IsHidden(I);
}

bool ListingItem::operator ==(const ListingItem&_) const noexcept
{
    return I == _.I && L == _.L;
}

bool ListingItem::operator !=(const ListingItem&_) const noexcept
{
    return I != _.I || L != _.L;
}

WeakListingItem::WeakListingItem() noexcept
{
}

WeakListingItem::WeakListingItem(const ListingItem &_item) noexcept:
    L(_item.L),
    I(_item.I)
{
}

WeakListingItem::WeakListingItem(const WeakListingItem &_item) noexcept:
    L(_item.L),
    I(_item.I)
{
}

WeakListingItem::WeakListingItem(WeakListingItem &&_item) noexcept:
    L( move(_item.L) ),
    I( _item.I )
{
}

const WeakListingItem& WeakListingItem::operator=( const ListingItem &_item ) noexcept
{
    L = _item.L;
    I = _item.I;
    return *this;
}

const WeakListingItem& WeakListingItem::operator=( const WeakListingItem &_item ) noexcept
{
    L = _item.L;
    I = _item.I;
    return *this;
}

const WeakListingItem& WeakListingItem::operator=( WeakListingItem &&_item ) noexcept
{
    L = move(_item.L);
    I = _item.I;
    return *this;
}

ListingItem WeakListingItem::Lock() const noexcept
{
    return { L.lock(), I };
}

bool WeakListingItem::operator ==(const WeakListingItem&_) const noexcept
{
    return I == _.I && !L.owner_before(_.L) && !_.L.owner_before(L);
}

bool WeakListingItem::operator !=(const WeakListingItem&_) const noexcept
{
    return !(*this == _);
}

bool WeakListingItem::operator ==(const ListingItem&_) const noexcept
{
    return I == _.I && !L.owner_before(_.L) && !_.L.owner_before(L);
}

bool WeakListingItem::operator !=(const ListingItem&_) const noexcept
{
    return !(*this == _);
}

bool operator==(const ListingItem&_l, const WeakListingItem&_r) noexcept
{
    return _r == _l;
}

bool operator!=(const ListingItem&_l, const WeakListingItem&_r) noexcept
{
    return !(_r == _l);
}

/**
 * VFSListing::iterator
 *///////
Listing::iterator &Listing::iterator::operator--() noexcept // prefix decrement
{
    i.I--;
    return *this;
}

Listing::iterator &Listing::iterator::operator++() noexcept // prefix increment
{
    i.I++;
    return *this;
}
Listing::iterator Listing::iterator::operator--(int) noexcept // posfix decrement
{
    auto p = *this;
    i.I--;
    return p;
}

Listing::iterator Listing::iterator::operator++(int) noexcept // posfix increment
{
    auto p = *this;
    i.I++;
    return p;
}
    
bool Listing::iterator::operator==(const iterator& _r) const noexcept
{
    return i.I == _r.i.I && i.L == _r.i.L;
}

bool Listing::iterator::operator!=(const iterator& _r) const noexcept
{
    return !(*this == _r);
}

const ListingItem& Listing::iterator::operator*() const noexcept
{
    return i;
}

}
