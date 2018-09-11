#pragma once

#include "IconRepository.h"
#include "IconBuilder.h"

namespace nc::vfsicon {

namespace detail {
 
struct IconRepositoryImplBase
{
    struct Executor {
        virtual ~Executor() = default;
        virtual void Execute( std::function<void()> _block ) = 0;
    };
    struct MainQueueExecutor : Executor {
        void Execute( std::function<void()> _block ) override;
        static MainQueueExecutor instance;
    };
};

}
    
class IconRepositoryImpl final :
    public IconRepository,
    private detail::IconRepositoryImplBase
{
public:
    IconRepositoryImpl(const std::shared_ptr<IconBuilder> &_icon_builder,
                       Executor &_results_executor = MainQueueExecutor::instance);
    ~IconRepositoryImpl();
    
    bool IsValidSlot( SlotKey _key ) const override;
    NSImage *AvailableIconForSlot( SlotKey _key ) const override;
    NSImage *AvailableIconForListingItem( const VFSListingItem &_item ) const override;
    
    SlotKey Register( const VFSListingItem &_item ) override;
    std::vector<SlotKey> AllSlots() const override;
    void Unregister( SlotKey _key ) override;
    
    void ScheduleIconProduction(SlotKey _key, const VFSListingItem &_item) override;
    
    void SetUpdateCallback( std::function<void(SlotKey, NSImage*)> _on_icon_updated ) override;
    void SetPxSize( int _px_size ) override;        
        
};
  
}
