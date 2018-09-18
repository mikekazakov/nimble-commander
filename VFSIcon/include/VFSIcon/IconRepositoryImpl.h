// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "IconRepository.h"
#include "IconBuilder.h"
#include <atomic>
#include <queue>
#include <vector>
#include <stack>
#include <Habanero/spinlock.h>
#include <Habanero/intrusive_ptr.h>
//#include <boost/smart_ptr/intrusive_ptr.hpp>
//#include <boost/smart_ptr/intrusive_ref_counter.hpp>

namespace nc::vfsicon {

namespace detail {
 
struct IconRepositoryImplBase
{
    struct Executor {
        virtual ~Executor() = default;
        virtual void Execute( std::function<void()> _block ) = 0;
    };
    struct MainQueueExecutor final : Executor {
        void Execute( std::function<void()> _block ) override;
        static const std::shared_ptr<Executor> instance;
    };
    struct LimitedConcurrentQueue {
        virtual ~LimitedConcurrentQueue() = default;
        virtual void Execute( std::function<void()> _block ) = 0;
        virtual int QueueLength() const = 0;
    };
    class GCDLimitedConcurrentQueue final : public LimitedConcurrentQueue {
    public:
        GCDLimitedConcurrentQueue( short _concurrency_limit );
        ~GCDLimitedConcurrentQueue();
        void Execute( std::function<void()> _block ) override;
        int QueueLength() const override;
    private:
        void RunBlock( const std::function<void()> &_client_block );
        void DispatchForAsynExecution( std::function<void()> _client_block );
        std::atomic_int m_Scheduled{0};
        mutable spinlock m_AwaitingLock;        
        const short m_Concurrency;
        dispatch_group_t m_Group;
        dispatch_queue_t m_Queue;
        std::queue<std::function<void()>> m_Awaiting;
    };
};

}

class IconRepositoryImpl final :
    public IconRepository,
    private detail::IconRepositoryImplBase
{
public:
    IconRepositoryImpl
    (const std::shared_ptr<IconBuilder> &_icon_builder,
     std::unique_ptr<LimitedConcurrentQueue> _production_queue,
     const std::shared_ptr<Executor> &_client_executor = MainQueueExecutor::instance,
     int _max_prod_queue_length = 512,
     int _capacity = std::numeric_limits<SlotKey>::max());
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
    
private:
    
    struct WorkerContext : hbn::intrusive_ref_counter<WorkerContext> {
        VFSListingItem item;
        std::atomic_bool must_stop{false};
        NSImage *result_filetype = nil;
        NSImage *result_thumbnail = nil;        
    };
    
    enum class SlotState {
        Empty       = 0,
        Initial     = 1,
        Production  = 2
    };
    
    // SlotKeys are slot indices offseted by 1: [0]->1, [1]->2 etc.    
    struct Slot {
        SlotState state = SlotState::Empty;
        mode_t file_mode = 0;
        uint64_t file_size = 0;
        time_t file_mtime = 0;
        NSImage *icon = nil;
        hbn::intrusive_ptr<WorkerContext> production;
    };
    
    int NumberOfUsedSlots() const;
    int AllocateSlot();
    void ProduceRealIcon(WorkerContext &_ctx);
    void CommitProductionResult(int _slot_index, WorkerContext &_ctx);
    static bool RefreshImages(Slot& _slot, const WorkerContext &_ctx);
    static bool HasFileChanged(const Slot& _slot, const VFSListingItem &_item);
    static NSImage* BestImageFromSlot(const Slot& _slot);
    static bool IsSlotUsed(const Slot& _slot);
    static SlotKey FromIndex(int _index);
    static int ToIndex(SlotKey _key);
    
    std::vector<Slot> m_Slots;
    std::stack<int> m_FreeSlotsIndices;
    int m_IconPxSize = 32;
    const int m_Capacity;
    const int m_MaxQueueLength;
    std::shared_ptr<IconBuilder> m_IconBuilder;
    std::shared_ptr<Executor> m_ClientExecutor;
    std::unique_ptr<LimitedConcurrentQueue> m_ProductionQueue;
    std::shared_ptr<std::function<void(SlotKey, NSImage*)>> m_IconUpdatedCallback;
};
  
}
