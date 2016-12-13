#include "PanelViewLayoutSupport.h"

//struct PanelViewLayout
//{
//    string name; // for the future
//    any layout; // perhaps switch to variant?
//    // may be PanelListViewColumnsLayout, PanelBriefViewColumnsLayout or
//    // PanelViewDisabledLayout at the moment.
bool PanelViewLayout::is_disabled() const
{
    return  any_cast<PanelViewDisabledLayout>(&layout) != nullptr;
}

PanelViewLayout::Type PanelViewLayout::type() const
{
    if( any_cast<PanelListViewColumnsLayout>(&layout) )
        return Type::List;
    if( any_cast<PanelBriefViewColumnsLayout>(&layout) )
        return Type::Brief;
    return Type::Disabled;
}

const PanelBriefViewColumnsLayout *PanelViewLayout::brief() const
{
    return any_cast<PanelBriefViewColumnsLayout>(&layout);
}

const PanelListViewColumnsLayout *PanelViewLayout::list() const
{
    return any_cast<PanelListViewColumnsLayout>(&layout);
}

bool PanelViewLayout::operator==(const PanelViewLayout& _rhs) const
{
    if( this == &_rhs )
        return true;
    
    if( name != _rhs.name || type() != _rhs.type() )
        return false;
    
    switch( type() ) {
        case Type::Brief:   return *brief() == *_rhs.brief();
        case Type::List:    return *list() == *_rhs.list();
        default:            return true;
    }
}

bool PanelViewLayout::operator!=(const PanelViewLayout& _rhs) const
{
    return !(*this == _rhs);
}

static PanelViewLayout L1()
{
    
    //    struct PanelBriefViewColumnsLayout
    //    {
    //        enum class Mode : short {
    //            FixedWidth      = 0,
    //            FixedAmount     = 1,
    //            DynamicWidth    = 2
    //        };
    //        Mode    mode                = Mode::FixedAmount;
    //        short   fixed_mode_width    = 150;
    //        short   fixed_amount_value  = 3;
    //        short   dynamic_width_min   = 100;
    //        short   dynamic_width_max   = 300;
    //        bool    dynamic_width_equal = false;
    
    PanelBriefViewColumnsLayout cl;
    cl.mode = PanelBriefViewColumnsLayout::Mode::FixedAmount;
    cl.fixed_amount_value = 3;
    
    PanelViewLayout ret;
    ret.layout = cl;
    ret.name = "Short";
    return ret;
}

static PanelViewLayout L2()
{
    
    //    struct PanelBriefViewColumnsLayout
    //    {
    //        enum class Mode : short {
    //            FixedWidth      = 0,
    //            FixedAmount     = 1,
    //            DynamicWidth    = 2
    //        };
    //        Mode    mode                = Mode::FixedAmount;
    //        short   fixed_mode_width    = 150;
    //        short   fixed_amount_value  = 3;
    //        short   dynamic_width_min   = 100;
    //        short   dynamic_width_max   = 300;
    //        bool    dynamic_width_equal = false;
    
    PanelBriefViewColumnsLayout cl;
    cl.mode = PanelBriefViewColumnsLayout::Mode::DynamicWidth;
    
    PanelViewLayout ret;
    ret.layout = cl;
    ret.name = "Medium";
    return ret;
}

static PanelViewLayout L3()
{
    PanelListViewColumnsLayout l;
    
    PanelListViewColumnsLayout::Column c;
    c.kind = PanelListViewColumns::Filename;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::Size;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::DateCreated;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::DateModified;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::DateAdded;
    l.columns.emplace_back(c);
    
    PanelViewLayout ret;
    ret.layout = l;
    ret.name = "Full";
    return ret;
}

static PanelViewLayout L4()
{
    PanelListViewColumnsLayout l;
    
    PanelListViewColumnsLayout::Column c;
    c.kind = PanelListViewColumns::Filename;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::Size;
    l.columns.emplace_back(c);
    
    PanelViewLayout ret;
    ret.layout = l;
    ret.name = "Wide";
    return ret;
}

PanelViewLayoutsStorage::PanelViewLayoutsStorage()
{
    m_Layouts.emplace_back( make_shared<PanelViewLayout>(L1()) );
    m_Layouts.emplace_back( make_shared<PanelViewLayout>(L2()) );
    m_Layouts.emplace_back( make_shared<PanelViewLayout>(L3()) );
    m_Layouts.emplace_back( make_shared<PanelViewLayout>(L4()) );
    
}

int PanelViewLayoutsStorage::LayoutsCount() const
{
    lock_guard<spinlock> lock(m_LayoutsLock);
    return (int)m_Layouts.size();
}

shared_ptr<const PanelViewLayout>  PanelViewLayoutsStorage::GetLayout( int _index ) const
{
    lock_guard<spinlock> lock(m_LayoutsLock);
    return (_index >= 0 && _index < m_Layouts.size()) ?
        m_Layouts[_index] :
        nullptr;
}

vector<shared_ptr<const PanelViewLayout>> PanelViewLayoutsStorage::GetAllLayouts() const
{
    lock_guard<spinlock> lock(m_LayoutsLock);
    return m_Layouts;
}

const shared_ptr<const PanelViewLayout>& PanelViewLayoutsStorage::LastResortLayout() const
{
    static const shared_ptr<const PanelViewLayout> l = make_shared<PanelViewLayout>( L1() );
    return l;
}

void PanelViewLayoutsStorage::ReplaceLayout( PanelViewLayout _layout, int _at_index )
{
//    LOCK_GUARD(m_ToolsLock) {
//        if( _at_index >= m_Tools.size() )
//            return;
//        if( *m_Tools[_at_index] == _tool )
//            return; // do nothing if _tool is equal
//        m_Tools[_at_index] = make_shared<ExternalTool>( move(_tool) );
//    }
//    CommitChanges();

    LOCK_GUARD(m_LayoutsLock) {
        if( _at_index < 0 || _at_index >= m_Layouts.size() )
            return;
        if( *m_Layouts[_at_index] == _layout )
            return; // nothing to do - equal layouts
        m_Layouts[_at_index] = make_shared<PanelViewLayout>( move(_layout) );
    }
    
    FireObservers();
    
    // notify and commit
}

PanelViewLayoutsStorage::ObservationTicket PanelViewLayoutsStorage::ObserveChanges( function<void()> _callback )
{
    return AddObserver( move(_callback) );
}
