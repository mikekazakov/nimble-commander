#include "../../Files/Config.h"
#include "InternalViewerHistory.h"

static const auto g_StatePath                   = "viewer.history";
static const auto g_ConfigMaximumHistoryEntries = "viewer.maximumHistoryEntries";
static const auto g_ConfigSaveFileEnconding     = "viewer.saveFileEncoding";
static const auto g_ConfigSaveFileMode          = "viewer.saveFileMode";
static const auto g_ConfigSaveFilePosition      = "viewer.saveFilePosition";
static const auto g_ConfigSaveFileWrapping      = "viewer.saveFileWrapping";
static const auto g_ConfigSaveFileSelection     = "viewer.saveFileSelection";

InternalViewerHistory::InternalViewerHistory( GenericConfig &_state_config, const char *_config_path ):
    m_StateConfig(_state_config),
    m_StateConfigPath(_config_path),
    m_Limit( max(0, min(GlobalConfig().GetInt(g_ConfigMaximumHistoryEntries), 4096)) )
{
//    // Wire up notification about application shutdown
//    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification
//                                                    object:nil
//                                                     queue:nil
//                                                usingBlock:^(NSNotification * _Nonnull note) {
//                                                    m_Config.Commit();
//                                                }];
    LoadSaveOptions();
    GlobalConfig().ObserveMany(m_ConfigObservations,
                               [=]{ LoadSaveOptions(); },
                               initializer_list<const char *>{
                                   g_ConfigSaveFileEnconding,
                                   g_ConfigSaveFileMode,
                                   g_ConfigSaveFilePosition,
                                   g_ConfigSaveFileWrapping,
                                   g_ConfigSaveFileSelection}
                               );
}

InternalViewerHistory& InternalViewerHistory::Instance()
{
    static auto history = new InternalViewerHistory( StateConfig(), g_StatePath );
    return *history;
}

void InternalViewerHistory::AddEntry( Entry _entry )
{
    LOCK_GUARD(m_HistoryLock) {
        auto it = find_if( begin(m_History), end(m_History), [&](auto &_i){
            return _i.path == _entry.path;
        });
        if( it != end(m_History) )
            m_History.erase(it);
        m_History.push_front( move(_entry) );
        
        while( m_History.size() >= m_Limit )
            m_History.pop_back();
    }
}

optional<InternalViewerHistory::Entry> InternalViewerHistory::EntryByPath( const string &_path ) const
{
    LOCK_GUARD(m_HistoryLock) {
        auto it = find_if( begin(m_History), end(m_History), [&](auto &_i){
            return _i.path == _path;
        });
        if( it != end(m_History) )
            return *it;
    }
    return nullopt;
}

void InternalViewerHistory::LoadSaveOptions()
{
    m_Options.encoding    = GlobalConfig().GetBool(g_ConfigSaveFileEnconding);
    m_Options.mode        = GlobalConfig().GetBool(g_ConfigSaveFileMode);
    m_Options.position    = GlobalConfig().GetBool(g_ConfigSaveFilePosition);
    m_Options.wrapping    = GlobalConfig().GetBool(g_ConfigSaveFileWrapping);
    m_Options.selection   = GlobalConfig().GetBool(g_ConfigSaveFileSelection);
}

InternalViewerHistory::SaveOptions InternalViewerHistory::Options() const
{
    return m_Options;
}

bool InternalViewerHistory::Enabled() const
{
    auto options = Options();
    return options.encoding || options.mode || options.position || options.wrapping || options.selection;
}
