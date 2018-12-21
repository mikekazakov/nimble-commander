// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SettingsAdaptor.h"
#include <Term/Settings.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::term {

static const auto g_ConfigMaxFPS = "terminal.maxFPS";
static const auto g_ConfigCursorMode = "terminal.cursorMode";
static const auto g_ConfigHideScrollbar = "terminal.hideVerticalScrollbar";
    
class SettingsImpl : public DefaultSettings
{
    ThemesManager::ObservationTicket m_ThemeObservation;
    std::vector<config::Token> m_ConfigObservationTickets;
    std::vector<std::pair<int, std::function<void()>>> m_Callbacks;
    int m_LastTicket = 1;
public:
    SettingsImpl()
    {
        m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::Terminal,
            []{ DispatchNotification();
        });
        GlobalConfig().ObserveMany(
            m_ConfigObservationTickets,
            []{ DispatchNotification(); },
            std::initializer_list<const char*>{g_ConfigCursorMode}
        );
    }
    
    int StartChangesObserving( std::function<void()> _callback ) override
    {
        dispatch_assert_main_queue();
        if( !_callback )
            return 0;
        const auto ticket = m_LastTicket++;
        m_Callbacks.emplace_back(ticket, move(_callback));
        return ticket;
    }
    
    void StopChangesObserving( int _ticket ) override
    {
        dispatch_assert_main_queue();
        if( _ticket > 0 )
            m_Callbacks.erase(
                remove_if(
                    begin(m_Callbacks),
                    end(m_Callbacks),
                    [_ticket](const auto &v) { return v.first == _ticket; }
                    ),
                end(m_Callbacks)
            );
    }
    
    void FireNotification() const
    {
        dispatch_assert_main_queue();
        for( const auto &c: m_Callbacks )
            c.second();
    }
    
    static void DispatchNotification()
    {
        if( dispatch_is_main_queue() )
            std::dynamic_pointer_cast<SettingsImpl>(TerminalSettings())->FireNotification();
        else
            dispatch_to_main_queue([]{
                std::dynamic_pointer_cast<SettingsImpl>(TerminalSettings())->FireNotification();
            });
    }
    
    NSFont  *Font() const override { return CurrentTheme().TerminalFont(); }
    NSColor *ForegroundColor() const override { return CurrentTheme().TerminalForegroundColor(); }
    NSColor *BoldForegroundColor() const override { return CurrentTheme().TerminalBoldForegroundColor(); };
    NSColor *BackgroundColor() const override { return CurrentTheme().TerminalBackgroundColor(); }
    NSColor *SelectionColor() const override { return CurrentTheme().TerminalSelectionColor(); }
    NSColor *CursorColor() const override { return CurrentTheme().TerminalCursorColor(); }
    NSColor *AnsiColor0() const override { return CurrentTheme().TerminalAnsiColor0(); }
    NSColor *AnsiColor1() const override { return CurrentTheme().TerminalAnsiColor1(); }
    NSColor *AnsiColor2() const override { return CurrentTheme().TerminalAnsiColor2(); }
    NSColor *AnsiColor3() const override { return CurrentTheme().TerminalAnsiColor3(); }
    NSColor *AnsiColor4() const override { return CurrentTheme().TerminalAnsiColor4(); }
    NSColor *AnsiColor5() const override { return CurrentTheme().TerminalAnsiColor5(); }
    NSColor *AnsiColor6() const override { return CurrentTheme().TerminalAnsiColor6(); }
    NSColor *AnsiColor7() const override { return CurrentTheme().TerminalAnsiColor7(); }
    NSColor *AnsiColor8() const override { return CurrentTheme().TerminalAnsiColor8(); }
    NSColor *AnsiColor9() const override { return CurrentTheme().TerminalAnsiColor9(); }
    NSColor *AnsiColorA() const override { return CurrentTheme().TerminalAnsiColorA(); }
    NSColor *AnsiColorB() const override { return CurrentTheme().TerminalAnsiColorB(); }
    NSColor *AnsiColorC() const override { return CurrentTheme().TerminalAnsiColorC(); }
    NSColor *AnsiColorD() const override { return CurrentTheme().TerminalAnsiColorD(); }
    NSColor *AnsiColorE() const override { return CurrentTheme().TerminalAnsiColorE(); }
    NSColor *AnsiColorF() const override { return CurrentTheme().TerminalAnsiColorF(); }
    int MaxFPS() const override { return GlobalConfig().GetInt(g_ConfigMaxFPS); }
    enum CursorMode CursorMode() const override {
        return  (enum CursorMode)GlobalConfig().GetInt(g_ConfigCursorMode);
    }
    bool HideScrollbar() const override {
        return GlobalConfig().GetBool(g_ConfigHideScrollbar);
    }
};
    
std::shared_ptr<Settings> TerminalSettings()
{
    static const auto settings = std::make_shared<SettingsImpl>();
    return settings;
}

}
