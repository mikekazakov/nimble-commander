// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewLayoutSupport.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include <Config/RapidJSON.h>
#include <Base/dispatch_cpp.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>

// struct PanelViewLayout
//{
//    string name; // for the future
//    any layout; // perhaps switch to variant?
//    // may be PanelListViewColumnsLayout, PanelBriefViewColumnsLayout or
//    // PanelViewDisabledLayout at the moment.

using namespace nc::panel;

namespace nc::panel {

bool PanelViewLayout::is_disabled() const
{
    return std::any_cast<PanelViewDisabledLayout>(&layout) != nullptr;
}

PanelViewLayout::Type PanelViewLayout::type() const
{
    if( std::any_cast<PanelListViewColumnsLayout>(&layout) )
        return Type::List;
    if( std::any_cast<PanelBriefViewColumnsLayout>(&layout) )
        return Type::Brief;
    return Type::Disabled;
}

const PanelBriefViewColumnsLayout *PanelViewLayout::brief() const
{
    return std::any_cast<PanelBriefViewColumnsLayout>(&layout);
}

const PanelListViewColumnsLayout *PanelViewLayout::list() const
{
    return std::any_cast<PanelListViewColumnsLayout>(&layout);
}

bool PanelViewLayout::operator==(const PanelViewLayout &_rhs) const
{
    if( this == &_rhs )
        return true;

    if( name != _rhs.name )
        return false;

    const auto mytype = type();
    if( mytype != _rhs.type() )
        return false;

    switch( mytype ) {
        case Type::Brief:
            return *brief() == *_rhs.brief();
        case Type::List:
            return *list() == *_rhs.list();
        default:
            return true;
    }
}

bool PanelViewLayout::operator!=(const PanelViewLayout &_rhs) const
{
    return !(*this == _rhs);
}

static const auto g_TitleKey = "title";
static const auto g_BriefKey = "brief";
static const auto g_BriefModeKey = "mode";
static const auto g_BriefFixedModeWidthKey = "fixed_mode_width";
static const auto g_BriefFixedAmountValueKey = "fixed_amount_value";
static const auto g_BriefDynamicWidthMinKey = "dynamic_width_min";
static const auto g_BriefDynamicWidthMaxKey = "dynamic_width_max";
static const auto g_BriefDynamicWidthEqualKey = "dynamic_width_equal";
static const auto g_BriefIconScale = "icon_scale";
static const auto g_ListKey = "list";
static const auto g_ListColumns = "columns";
static const auto g_ListColumKind = "kind";
static const auto g_ListColumWidth = "width";
static const auto g_ListColumMaxWidth = "max_width";
static const auto g_ListColumMinWidth = "min_width";
static const auto g_ListIconScale = "icon_scale";
static const auto g_DisabledKey = "disabled";

static config::Value SaveLayout(const PanelViewLayout &_l)
{
    using namespace rapidjson;
    using namespace nc::config;
    config::Value v{kObjectType};

    v.AddMember(MakeStandaloneString(g_TitleKey), MakeStandaloneString(_l.name), g_CrtAllocator);
    if( auto list = _l.list() ) {
        config::Value d{kObjectType};
        config::Value columns{rapidjson::kArrayType};
        for( auto &c : list->columns ) {
            config::Value col{kObjectType};
            col.AddMember(
                MakeStandaloneString(g_ListColumKind), config::Value(static_cast<int>(c.kind)), g_CrtAllocator);
            if( c.width >= 0 )
                col.AddMember(MakeStandaloneString(g_ListColumWidth), config::Value(c.width), g_CrtAllocator);
            if( c.min_width >= 0 )
                col.AddMember(MakeStandaloneString(g_ListColumMinWidth), config::Value(c.min_width), g_CrtAllocator);
            if( c.max_width >= 0 )
                col.AddMember(MakeStandaloneString(g_ListColumMaxWidth), config::Value(c.max_width), g_CrtAllocator);
            columns.PushBack(std::move(col), g_CrtAllocator);
        }
        d.AddMember(MakeStandaloneString(g_ListColumns), std::move(columns), g_CrtAllocator);
        d.AddMember(MakeStandaloneString(g_ListIconScale), config::Value(list->icon_scale), g_CrtAllocator);
        v.AddMember(MakeStandaloneString(g_ListKey), std::move(d), g_CrtAllocator);
    }
    else if( auto brief = _l.brief() ) {
        config::Value d{kObjectType};
        d.AddMember(MakeStandaloneString(g_BriefModeKey), config::Value(static_cast<int>(brief->mode)), g_CrtAllocator);
        d.AddMember(
            MakeStandaloneString(g_BriefFixedModeWidthKey), config::Value(brief->fixed_mode_width), g_CrtAllocator);
        d.AddMember(
            MakeStandaloneString(g_BriefFixedAmountValueKey), config::Value(brief->fixed_amount_value), g_CrtAllocator);
        d.AddMember(
            MakeStandaloneString(g_BriefDynamicWidthMinKey), config::Value(brief->dynamic_width_min), g_CrtAllocator);
        d.AddMember(
            MakeStandaloneString(g_BriefDynamicWidthMaxKey), config::Value(brief->dynamic_width_max), g_CrtAllocator);
        d.AddMember(MakeStandaloneString(g_BriefDynamicWidthEqualKey),
                    config::Value(brief->dynamic_width_equal),
                    g_CrtAllocator);
        d.AddMember(MakeStandaloneString(g_BriefIconScale), config::Value(brief->icon_scale), g_CrtAllocator);
        v.AddMember(MakeStandaloneString(g_BriefKey), std::move(d), g_CrtAllocator);
    }
    else if( _l.is_disabled() ) {
        v.AddMember(MakeStandaloneString(g_DisabledKey), config::Value{kNullType}, g_CrtAllocator);
    }

    return v;
}

static std::optional<PanelViewLayout> LoadLayout(const config::Value &_from)
{
    using namespace rapidjson;
    if( !_from.IsObject() )
        return std::nullopt;

    PanelViewLayout l;
    if( _from.HasMember(g_TitleKey) && _from[g_TitleKey].IsString() )
        l.name = _from[g_TitleKey].GetString();
    else
        return std::nullopt;

    if( _from.HasMember(g_BriefKey) && _from[g_BriefKey].IsObject() ) {
        auto &o = _from[g_BriefKey];
        PanelBriefViewColumnsLayout brief;
        if( o.HasMember(g_BriefModeKey) && o[g_BriefModeKey].IsNumber() )
            brief.mode = static_cast<PanelBriefViewColumnsLayout::Mode>(o[g_BriefModeKey].GetInt());
        if( o.HasMember(g_BriefFixedModeWidthKey) && o[g_BriefFixedModeWidthKey].IsNumber() )
            brief.fixed_mode_width = static_cast<short>(o[g_BriefFixedModeWidthKey].GetInt());
        if( o.HasMember(g_BriefFixedAmountValueKey) && o[g_BriefFixedAmountValueKey].IsNumber() )
            brief.fixed_amount_value = static_cast<short>(o[g_BriefFixedAmountValueKey].GetInt());
        if( o.HasMember(g_BriefDynamicWidthMinKey) && o[g_BriefDynamicWidthMinKey].IsNumber() )
            brief.dynamic_width_min = static_cast<short>(o[g_BriefDynamicWidthMinKey].GetInt());
        if( o.HasMember(g_BriefDynamicWidthMaxKey) && o[g_BriefDynamicWidthMaxKey].IsNumber() )
            brief.dynamic_width_max = static_cast<short>(o[g_BriefDynamicWidthMaxKey].GetInt());
        if( o.HasMember(g_BriefDynamicWidthEqualKey) && o[g_BriefDynamicWidthEqualKey].IsBool() )
            brief.dynamic_width_equal = o[g_BriefDynamicWidthEqualKey].GetBool();
        if( o.HasMember(g_BriefIconScale) && o[g_BriefIconScale].IsInt() )
            brief.icon_scale = static_cast<uint8_t>(o[g_BriefIconScale].GetInt());
        l.layout = brief;
    }
    else if( _from.HasMember(g_ListKey) && _from[g_ListKey].IsObject() ) {
        auto &o = _from[g_ListKey];
        PanelListViewColumnsLayout list;
        if( !o.HasMember(g_ListColumns) || !o[g_ListColumns].IsArray() )
            return std::nullopt;
        for( auto i = o[g_ListColumns].Begin(), e = o[g_ListColumns].End(); i != e; ++i ) {
            if( !i->IsObject() )
                return std::nullopt;
            PanelListViewColumnsLayout::Column col;
            if( i->HasMember(g_ListColumKind) && (*i)[g_ListColumKind].IsNumber() )
                col.kind = static_cast<PanelListViewColumns>((*i)[g_ListColumKind].GetInt());
            if( i->HasMember(g_ListColumWidth) && (*i)[g_ListColumWidth].IsNumber() )
                col.width = static_cast<short>((*i)[g_ListColumWidth].GetInt());
            if( i->HasMember(g_ListColumMinWidth) && (*i)[g_ListColumMinWidth].IsNumber() )
                col.min_width = static_cast<short>((*i)[g_ListColumMinWidth].GetInt());
            if( i->HasMember(g_ListColumMaxWidth) && (*i)[g_ListColumMaxWidth].IsNumber() )
                col.max_width = static_cast<short>((*i)[g_ListColumMaxWidth].GetInt());
            list.columns.emplace_back(col);
        }
        if( o.HasMember(g_ListIconScale) && o[g_ListIconScale].IsInt() )
            list.icon_scale = static_cast<uint8_t>(o[g_ListIconScale].GetInt());
        l.layout = list;
    }
    else if( _from.HasMember(g_DisabledKey) )
        l.layout = PanelViewDisabledLayout{};
    else
        return std::nullopt;

    return l;
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

PanelViewLayoutsStorage::PanelViewLayoutsStorage(const char *_config_path) : m_ConfigPath(_config_path)
{
    LoadLayoutsFromConfig();
}

int PanelViewLayoutsStorage::LayoutsCount() const
{
    const std::lock_guard<spinlock> lock(m_LayoutsLock);
    return static_cast<int>(m_Layouts.size());
}

std::shared_ptr<const PanelViewLayout> PanelViewLayoutsStorage::GetLayout(int _index) const
{
    const std::lock_guard<spinlock> lock(m_LayoutsLock);
    return (_index >= 0 && _index < static_cast<int>(m_Layouts.size())) ? m_Layouts[_index] : nullptr;
}

std::vector<std::shared_ptr<const PanelViewLayout>> PanelViewLayoutsStorage::GetAllLayouts() const
{
    const std::lock_guard<spinlock> lock(m_LayoutsLock);
    return m_Layouts;
}

const std::shared_ptr<const PanelViewLayout> PanelViewLayoutsStorage::LastResortLayout()
{
    [[clang::no_destroy]] static const std::shared_ptr<const PanelViewLayout> l =
        std::make_shared<PanelViewLayout>(L1());
    return l;
}

const std::shared_ptr<const PanelViewLayout> PanelViewLayoutsStorage::DefaultLayout() const
{
    for( int i = 1; i >= 0; --i )
        if( auto l = GetLayout(i) )
            if( !l->is_disabled() )
                return l;
    return LastResortLayout();
}

int PanelViewLayoutsStorage::DefaultLayoutIndex() const
{
    for( int i = 1; i >= 0; --i )
        if( auto l = GetLayout(i) )
            if( !l->is_disabled() )
                return i;
    return -1;
}

void PanelViewLayoutsStorage::ReplaceLayout(PanelViewLayout _layout, int _at_index)
{
    ReplaceLayout(std::move(_layout), _at_index, false);
}

void PanelViewLayoutsStorage::ReplaceLayoutWithMandatoryNotification(PanelViewLayout _layout, int _at_index)
{
    ReplaceLayout(std::move(_layout), _at_index, true);
}

void PanelViewLayoutsStorage::ReplaceLayout(PanelViewLayout _layout, int _at_index, bool _mandatory)
{
    {
        auto lock = std::lock_guard{m_LayoutsLock};
        if( _at_index < 0 || _at_index >= static_cast<int>(m_Layouts.size()) )
            return;
        if( *m_Layouts[_at_index] == _layout )
            return; // nothing to do - equal layouts
        m_Layouts[_at_index] = std::make_shared<PanelViewLayout>(std::move(_layout));
    }

    CommitChanges(_mandatory);
}

PanelViewLayoutsStorage::ObservationTicket PanelViewLayoutsStorage::ObserveChanges(std::function<void()> _callback)
{
    return AddObserver(std::move(_callback));
}

void PanelViewLayoutsStorage::LoadLayoutsFromConfig()
{
    auto layouts = GlobalConfig().Get(m_ConfigPath);
    if( !layouts.IsArray() )
        return;

    auto lock = std::lock_guard{m_LayoutsLock};
    m_Layouts.clear();
    for( auto i = layouts.Begin(), e = layouts.End(); i != e; ++i )
        if( auto l = LoadLayout(*i) )
            m_Layouts.emplace_back(std::make_shared<PanelViewLayout>(std::move(*l)));
        else
            m_Layouts.emplace_back(LastResortLayout());
}

void PanelViewLayoutsStorage::WriteLayoutsToConfig() const
{
    std::vector<std::shared_ptr<const PanelViewLayout>> layouts;
    {
        auto lock = std::lock_guard{m_LayoutsLock};
        layouts = m_Layouts;
    }

    config::Value json_layouts{rapidjson::kArrayType};
    for( auto &l : layouts )
        json_layouts.PushBack(SaveLayout(*l), config::g_CrtAllocator);
    GlobalConfig().Set(m_ConfigPath, json_layouts);
}

void PanelViewLayoutsStorage::CommitChanges(bool _fire_observers)
{
    if( _fire_observers )
        FireObservers();
    dispatch_to_background([this] { WriteLayoutsToConfig(); });
}

} // namespace nc::panel

@implementation PanelViewLayoutsMenuDelegate {
    bool m_IsDirty;
    PanelViewLayoutsStorage *m_Storage;
    PanelViewLayoutsStorage::ObservationTicket m_Ticket;
}

- (id)initWithStorage:(PanelViewLayoutsStorage &)_storage
{
    self = [super init];
    if( self ) {
        m_IsDirty = true;
        m_Storage = &_storage;
        m_Ticket = m_Storage->ObserveChanges(nc::objc_callback(self, @selector(layoutsHaveChanged)));
    }
    return self;
}

- (void)layoutsHaveChanged
{
    m_IsDirty = true;
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if( m_IsDirty && (menu.propertiesToUpdate & NSMenuPropertyItemTitle) ) {
        int index = 0;
        for( NSMenuItem *item in menu.itemArray ) {
            if( auto l = m_Storage->GetLayout(index) ) {
                item.title = l->name.empty() ? [NSString stringWithFormat:@"Layout #%d", index + 1]
                                             : [NSString stringWithUTF8StdString:l->name];
            }
            index++;
        }
        m_IsDirty = false;
    }
}

@end
