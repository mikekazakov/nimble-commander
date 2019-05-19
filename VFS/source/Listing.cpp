// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Listing.h"
#include "../include/VFS/Host.h"
#include "ListingInput.h"
#include <sys/param.h>

namespace nc::vfs {
    
using nc::base::variable_container;

static_assert( std::is_move_constructible<ListingItem>::value, "" );
static_assert( std::is_move_constructible<Listing::iterator>::value, "" );

static bool BasicDirectoryCheck(const std::string& _str)
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
        throw std::logic_error("VFSListingInput validation failed: hosts can't be sparse");
    
    for( auto i = 0u, e = _source.hosts.size(); i != e; ++i )
        if( _source.hosts[i] == nullptr )
            throw std::logic_error("VFSListingInput validation failed: host can't be nullptr");
    
    if( _source.directories.mode() == variable_container<>::type::sparse )
        throw std::logic_error("VFSListingInput validation failed: directories can't be sparse");

    for( auto i = 0u, e = _source.directories.size(); i != e; ++i )
        if( !BasicDirectoryCheck( _source.directories[i] ) )
            throw std::logic_error("VFSListingInput validation failed: invalid directory");
    
    for( auto &s: _source.filenames )
        if( s.empty() )
            throw std::logic_error("VFSListingInput validation failed: filename can't be empty");
    
    if( _source.display_filenames.mode() == variable_container<>::type::common && items_no > 1 )
        throw std::logic_error("VFSListingInput validation failed: dispay_filenames can't be common");

    if( _source.sizes.mode() == variable_container<>::type::common && items_no > 1 )
        throw std::logic_error("VFSListingInput validation failed: sizes can't be common");

    if( _source.inodes.mode() == variable_container<>::type::common && items_no > 1 )
        throw std::logic_error("VFSListingInput validation failed: inodes can't be common");

    if( _source.symlinks.mode() == variable_container<>::type::common && items_no > 1 )
        throw std::logic_error("VFSListingInput validation failed: symlinks can't be common");
    
    if(_source.hosts.mode() == variable_container<>::type::dense &&
       (int)_source.hosts.size() != items_no )
        throw std::logic_error("VFSListingInput validation failed: hosts amount is inconsistent");
    
    if(_source.directories.mode() == variable_container<>::type::dense &&
       (int)_source.directories.size() != items_no)
        throw std::logic_error("VFSListingInput validation failed: directories amount is inconsistent");
    
    if((int)_source.unix_modes.size() != items_no)
        throw std::logic_error("VFSListingInput validation failed: unix_modes amount is inconsistent");
    
    if((int)_source.unix_types.size() != items_no)
        throw std::logic_error("VFSListingInput validation failed: unix_types amount is inconsistent");
        
    
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

std::shared_ptr<Listing> Listing::Build(ListingInput &&_input)
{
    Validate( _input ); // will throw an exception on error
    Compress( _input );
    
    auto l = Alloc();
    l->m_Hosts = std::move(_input.hosts);
    l->m_Directories = std::move(_input.directories);
    l->m_Filenames = std::move(_input.filenames);
    l->m_DisplayFilenames = std::move(_input.display_filenames);
    l->BuildFilenames();
    
    l->m_Sizes = std::move(_input.sizes);
    l->m_Inodes = std::move(_input.inodes);
    l->m_ATimes = std::move(_input.atimes);
    l->m_BTimes = std::move(_input.btimes);
    l->m_CTimes = std::move(_input.ctimes);
    l->m_MTimes = std::move(_input.mtimes);
    l->m_AddTimes = std::move(_input.add_times);
    l->m_UnixModes = std::move(_input.unix_modes);
    l->m_UnixTypes = std::move(_input.unix_types);
    l->m_UIDS = std::move(_input.uids);
    l->m_GIDS = std::move(_input.gids);
    l->m_UnixFlags = std::move(_input.unix_flags);
    l->m_Symlinks = std::move(_input.symlinks);
    l->m_CreationTime = time(0);
    
    return l;
}

ListingInput Listing::Compose(const std::vector<std::shared_ptr<Listing>> &_listings)
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

ListingInput Listing::Compose(const std::vector<std::shared_ptr<Listing>> &_listings,
                              const std::vector<std::vector<unsigned> > &_items_indeces)
{
    if( _listings.size() != _items_indeces.size() )
        throw std::invalid_argument("VFSListing::Compose input containers has different sizes");
    
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
                throw std::invalid_argument("VFSListing::Compose: invalid index");
            
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
    
    return Build( std::move(result) );
}

const std::shared_ptr<Listing> &Listing::EmptyListing() noexcept
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

std::shared_ptr<Listing> Listing::Alloc()
{
    struct make_shared_enabler: public Listing {};
    return std::make_shared<make_shared_enabler>();
}

static CFString UTF8WithFallback(const std::string &_s)
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
        if( dot_it != std::string::npos &&
            dot_it != 0 &&
            dot_it != current.size()-1 )
            offset = uint16_t(dot_it+1);
        m_ExtensionOffsets[i] = offset;
    }
}

}
