// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "IconsGenerator2.h"
#include "PanelData.h"
#include "PanelDataItemVolatileData.h"

namespace nc::panel {

static const auto g_DummyImage = [[NSImage alloc] initWithSize:NSMakeSize(0,0)];

inline static int MaximumConcurrentRunnersForVFS(const VFSHostPtr &_host)
{
    return _host->IsNativeFS() ? 64 : 6;
}

inline NSImage *IconsGenerator2::IconStorage::Any() const
{
    if(thumbnail)
        return thumbnail;
    if(filetype)
        return filetype;
    return generic;
}

IconsGenerator2::IconsGenerator2(const std::shared_ptr<vfsicon::IconBuilder> &_icon_builder):
    m_IconBuilder(_icon_builder)
{
    m_WorkGroup.SetOnDry([=]{
        DrainStash();
    });
}

IconsGenerator2::~IconsGenerator2()
{
    m_Generation++;
    LOCK_GUARD( m_RequestsStashLock ) {
        m_RequestsStash = {};
    }
    m_WorkGroup.SetOnDry( nullptr );
    m_WorkGroup.Wait();
}

unsigned short IconsGenerator2::GetSuitablePositionForNewIcon()
{
    if( m_IconsHoles == 0 ) {
        assert( m_Icons.size() < MaxIcons );
        auto n = (unsigned short)m_Icons.size();
        m_Icons.emplace_back( IconStorage() );
        return n;
    }
    else {
        for( auto i = 0, e = (int)m_Icons.size(); i != e; ++i ) {
            if( !m_Icons[i] ) {
                m_Icons[i].emplace();
                --m_IconsHoles;
                return (unsigned short)i;
            }
        }
        assert( 0 );
    }
}

bool IconsGenerator2::IsFull() const
{
    return m_Icons.size() - m_IconsHoles >= MaxIcons;
}

bool IconsGenerator2::IsRequestsStashFull() const
{
    int amount = 0;
    LOCK_GUARD(m_RequestsStashLock) {
        amount = (int)m_RequestsStash.size();
    }
    return amount >= MaxStashedRequests;
}

NSImage *IconsGenerator2::ImageFor(const VFSListingItem &_item, data::ItemVolatileData &_item_vd)
{
    dispatch_assert_main_queue(); // STA api design
    assert( m_UpdateCallback );
    
    if( m_IconSize == 0 )
        return g_DummyImage;
    
    if( _item_vd.icon > 0 ) {
        // short path - we have an already produced icon
        
        int number = _item_vd.icon - 1;
        // sanity check - not founding meta with such number means sanity breach in calling module
        assert( number < (int)m_Icons.size() );
        
        const auto &is = m_Icons[number];
        assert( is );

        return is->Any(); // short path - return a stored icon from stash
        // check if Icon meta stored here is outdated
    }
    
    // long path: no icon - first request for this entry (or mb entry changed)
    // need to collect the appropriate info and put request into generating queue

    const auto lookup_result = m_IconBuilder->LookupExistingIcon(_item, IconSizeInPixels());
    
    if( IsFull() || IsRequestsStashFull() ) {
        // we're full - sorry
        if( lookup_result.thumbnail )
            return lookup_result.thumbnail;
        if( lookup_result.filetype )
            return lookup_result.filetype;
        return lookup_result.generic;
    }

    // build IconStorage
    unsigned short is_no = GetSuitablePositionForNewIcon();
    auto &is = *m_Icons[is_no];
    is.file_size = _item.Size();
    is.mtime = _item.MTime();
    is.thumbnail = lookup_result.thumbnail;
    is.filetype = lookup_result.filetype;
    is.generic = lookup_result.generic;
        
    _item_vd.icon = is_no+1;
    
//  build BuildRequest
    BuildRequest br;
    br.generation = m_Generation;
    br.filetype = is.filetype;
    br.thumbnail = is.thumbnail;
    br.icon_number = is_no;
    br.item = _item;
    
    RunOrStash( move(br) );

    return is.Any();
}

NSImage *IconsGenerator2::AvailableImageFor(const VFSListingItem &_item,
                                            data::ItemVolatileData _item_vd ) const
{
    dispatch_assert_main_queue(); // STA api design
    
    if( _item_vd.icon > 0 ) {
        const int number = _item_vd.icon - 1;
        assert( number < (int)m_Icons.size() );
        
        const auto &is = m_Icons[number];
        assert( is );

        return is->Any(); // short path - return a stored icon from stash
    }
    
    const auto lookup_result = m_IconBuilder->LookupExistingIcon(_item, IconSizeInPixels());    
    if( lookup_result.thumbnail )
        return lookup_result.thumbnail;
    if( lookup_result.filetype )
        return lookup_result.filetype;
    return lookup_result.generic;
}

void IconsGenerator2::RunOrStash( BuildRequest _req )
{
    dispatch_assert_main_queue(); // STA api design
    
    if( m_WorkGroup.Count() <= MaximumConcurrentRunnersForVFS( _req.item.Host() )  ) {
        // run task now
        m_WorkGroup.Run([=,request=move(_req)]{
            // went to background worker thread
            BackgroundWork( request );
        });
    }
    else {
        // stash request and fire it group becomes dry
        LOCK_GUARD( m_RequestsStashLock ) {
            m_RequestsStash.emplace( move(_req) );
        }
    }
}

void IconsGenerator2::DrainStash()
{
    // this is a background thread
    LOCK_GUARD( m_RequestsStashLock ) {
        while( !m_RequestsStash.empty() ) {
            if( m_WorkGroup.Count() > MaximumConcurrentRunnersForVFS( m_RequestsStash.front().item.Host() ) )
                break; // we load enough of workload
            
            m_WorkGroup.Run([=,request=move(m_RequestsStash.front())] {
                BackgroundWork( request ); // went to background worker thread
            });
            
            m_RequestsStash.pop();
        }
    }
}

void IconsGenerator2::BackgroundWork(const BuildRequest &_request)
{
    dispatch_assert_background_queue();
    auto checker = [this, generation=_request.generation] {
        return generation != this->m_Generation;
    };
    auto build_result = m_IconBuilder->BuildRealIcon(_request.item, IconSizeInPixels(), checker);
    if( _request.generation != m_Generation )
        return;
    
    // it's possible that background "heavy" images fetching did bring the same set of
    // images which were available initially with a shallow scan.
    // in this case there's no need to fire any callbacks. 
    const auto has_anything_to_commit =
        (build_result.thumbnail != nullptr && build_result.thumbnail != _request.thumbnail) ||
        (build_result.filetype != nullptr && build_result.filetype != _request.filetype);
    if( has_anything_to_commit == false )
        return;
    
    dispatch_to_main_queue([=,res=move(build_result)] {
        // returned to main thread
        if( _request.generation != m_Generation )
            return;
        
        const auto is_no = _request.icon_number;
        assert( is_no < m_Icons.size() ); // consistancy check
        
        if( auto &storage = m_Icons[is_no]; storage ) {
            if( res.filetype )
                storage->filetype = res.filetype;
            if( res.thumbnail )
                storage->thumbnail = res.thumbnail;
            m_UpdateCallback(is_no + 1, storage->Any());
        }
    });
}
    
void IconsGenerator2::SyncDiscardedAndOutdated( nc::panel::data::Model &_pd )
{
    assert(dispatch_is_main_queue()); // STA api design    
   
    vector<bool> sweep_mark( m_Icons.size(), true );
    vector<int> entries_to_update;
    
    const auto count = (int)_pd.RawEntriesCount();
    for( auto i = 0; i < count; ++i ) {
        auto &vd = _pd.VolatileDataAtRawPosition( i );
        if( vd.icon != 0 ) {
            auto is_no = vd.icon - 1;
            assert( m_Icons[is_no] );
            
            auto item = _pd.EntryAtRawPosition( i );
            
            if(m_Icons[is_no]->file_size != item.Size() &&
               m_Icons[is_no]->mtime != item.MTime() ) {
                // this icon might be outdated, drop it
                vd.icon = 0;
                entries_to_update.emplace_back(i);
            }
            else {
                // this icon is fine
                sweep_mark[is_no] = false;
            }
        }
    }

    for( int i = 0, e = (int)m_Icons.size(); i != e; ++i )
        if( m_Icons[i] && sweep_mark[i] ) {
            m_Icons[i] = nullopt;
            ++m_IconsHoles;
        }
    
    if( m_IconsHoles == (int)m_Icons.size() ) {
        // complete change on data - discard everything and increment generation
        m_Icons.clear();
        m_IconsHoles = 0;
        m_Generation++;
    }
    else {    
//        for( auto i: entries_to_update )
//            ImageFor( _pd.EntryAtRawPosition(i), _pd.VolatileDataAtRawPosition(i) );
    }
}

void IconsGenerator2::SetIconSize(int _size)
{
    assert(dispatch_is_main_queue()); // STA api design
    if( m_IconSize == _size )
        return;
    m_IconSize = _size;
    m_IconSizePx = m_HiDPI ? m_IconSize * 2 : m_IconSize;
}

void IconsGenerator2::SetUpdateCallback(function<void(uint16_t, NSImage*)> _cb)
{
    assert(dispatch_is_main_queue()); // STA api design
    m_UpdateCallback = move(_cb);
}

int IconsGenerator2::IconSizeInPixels() const noexcept
{
    return m_IconSizePx;
}

bool IconsGenerator2::HiDPI() const noexcept
{
    return m_HiDPI;
}

void IconsGenerator2::SetHiDPI( bool _is_hi_dpi )
{
    assert(dispatch_is_main_queue()); // STA api design     
    if( m_HiDPI == _is_hi_dpi )
        return;
    m_HiDPI = _is_hi_dpi;
    m_IconSizePx = m_HiDPI ? m_IconSize * 2 : m_IconSize;
}

int IconsGenerator2::IconSize() const noexcept
{
    return m_IconSize;
}

}
