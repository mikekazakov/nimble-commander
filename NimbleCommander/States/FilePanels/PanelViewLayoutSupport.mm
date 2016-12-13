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

const PanelViewLayout& PanelViewLayoutsStorage::LastResortLayout() const
{
    static const auto l = L1();
    return l;
}
