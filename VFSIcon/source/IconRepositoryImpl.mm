#include <VFSIcon/IconRepositoryImpl.h>

namespace nc::vfsicon {

IconRepositoryImpl::IconRepositoryImpl(const std::shared_ptr<IconBuilder> &_icon_builder,
                                       Executor &_results_executor)
{
        
}
    
IconRepositoryImpl::~IconRepositoryImpl()
{
}

    
bool IconRepositoryImpl::IsValidSlot( SlotKey _key ) const
{
    return false;
}
    
NSImage *IconRepositoryImpl::AvailableIconForSlot( SlotKey _key ) const
{
    return nil;
}
    
NSImage *IconRepositoryImpl::AvailableIconForListingItem( const VFSListingItem &_item ) const
{
    return nil;
}
    
IconRepositoryImpl::SlotKey IconRepositoryImpl::Register( const VFSListingItem &_item )
{
    return {};        
}
    
std::vector<IconRepositoryImpl::SlotKey> IconRepositoryImpl::AllSlots() const
{
    return {};        
}
    
void IconRepositoryImpl::Unregister( SlotKey _key )
{    
}
    
void IconRepositoryImpl::ScheduleIconProduction(SlotKey _key, const VFSListingItem &_item)
{        
}
    
void IconRepositoryImpl::SetUpdateCallback(std::function<void(SlotKey, NSImage*)> _on_icon_updated)
{
}

void IconRepositoryImpl::SetPxSize( int _px_size )
{        
}

namespace detail {
// 
//struct IconRepositoryImplBase
//{
//    struct Executor {
//        virtual ~Executor() = default;
//        virtual void Execute( std::function<void()> _block ) = 0;
//    };
//    struct MainQueueExecutor : Executor {
//        void Execute( std::function<void()> _block ) override;
//    };
//};

void IconRepositoryImplBase::MainQueueExecutor::Execute( std::function<void()> _block )
{
        
}

IconRepositoryImplBase::MainQueueExecutor IconRepositoryImplBase::MainQueueExecutor::instance{};
    
}
    
}
