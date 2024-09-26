// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SettingsAdaptor.h"
#include <Term/Settings.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <Base/dispatch_cpp.h>

#include <algorithm>

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
        m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(ThemesManager::Notifications::Terminal,
                                                                           [] { DispatchNotification(); });
        GlobalConfig().ObserveMany(
            m_ConfigObservationTickets,
            [] { DispatchNotification(); },
            std::initializer_list<const char *>{g_ConfigCursorMode});
    }

    int StartChangesObserving(std::function<void()> _callback) override
    {
        dispatch_assert_main_queue();
        if( !_callback )
            return 0;
        const auto ticket = m_LastTicket++;
        m_Callbacks.emplace_back(ticket, std::move(_callback));
        return ticket;
    }

    void StopChangesObserving(int _ticket) override
    {
        dispatch_assert_main_queue();
        if( _ticket > 0 )
            std::erase_if(m_Callbacks, [_ticket](const auto &v) { return v.first == _ticket; });
    }

    void FireNotification() const
    {
        dispatch_assert_main_queue();
        for( const auto &c : m_Callbacks )
            c.second();
    }

    static void DispatchNotification()
    {
        if( dispatch_is_main_queue() )
            std::dynamic_pointer_cast<SettingsImpl>(TerminalSettings())->FireNotification();
        else
            dispatch_to_main_queue(
                [] { std::dynamic_pointer_cast<SettingsImpl>(TerminalSettings())->FireNotification(); });
    }

    [[nodiscard]] NSFont *Font() const override { return CurrentTheme().TerminalFont(); }
    [[nodiscard]] NSColor *ForegroundColor() const override { return CurrentTheme().TerminalForegroundColor(); }
    [[nodiscard]] NSColor *BoldForegroundColor() const override
    {
        return CurrentTheme().TerminalBoldForegroundColor();
    };
    [[nodiscard]] NSColor *BackgroundColor() const override { return CurrentTheme().TerminalBackgroundColor(); }
    [[nodiscard]] NSColor *SelectionColor() const override { return CurrentTheme().TerminalSelectionColor(); }
    [[nodiscard]] NSColor *CursorColor() const override { return CurrentTheme().TerminalCursorColor(); }
    [[nodiscard]] NSColor *AnsiColor0() const override { return CurrentTheme().TerminalAnsiColor0(); }
    [[nodiscard]] NSColor *AnsiColor1() const override { return CurrentTheme().TerminalAnsiColor1(); }
    [[nodiscard]] NSColor *AnsiColor2() const override { return CurrentTheme().TerminalAnsiColor2(); }
    [[nodiscard]] NSColor *AnsiColor3() const override { return CurrentTheme().TerminalAnsiColor3(); }
    [[nodiscard]] NSColor *AnsiColor4() const override { return CurrentTheme().TerminalAnsiColor4(); }
    [[nodiscard]] NSColor *AnsiColor5() const override { return CurrentTheme().TerminalAnsiColor5(); }
    [[nodiscard]] NSColor *AnsiColor6() const override { return CurrentTheme().TerminalAnsiColor6(); }
    [[nodiscard]] NSColor *AnsiColor7() const override { return CurrentTheme().TerminalAnsiColor7(); }
    [[nodiscard]] NSColor *AnsiColor8() const override { return CurrentTheme().TerminalAnsiColor8(); }
    [[nodiscard]] NSColor *AnsiColor9() const override { return CurrentTheme().TerminalAnsiColor9(); }
    [[nodiscard]] NSColor *AnsiColorA() const override { return CurrentTheme().TerminalAnsiColorA(); }
    [[nodiscard]] NSColor *AnsiColorB() const override { return CurrentTheme().TerminalAnsiColorB(); }
    [[nodiscard]] NSColor *AnsiColorC() const override { return CurrentTheme().TerminalAnsiColorC(); }
    [[nodiscard]] NSColor *AnsiColorD() const override { return CurrentTheme().TerminalAnsiColorD(); }
    [[nodiscard]] NSColor *AnsiColorE() const override { return CurrentTheme().TerminalAnsiColorE(); }
    [[nodiscard]] NSColor *AnsiColorF() const override { return CurrentTheme().TerminalAnsiColorF(); }
    [[nodiscard]] int MaxFPS() const override { return GlobalConfig().GetInt(g_ConfigMaxFPS); }
    [[nodiscard]] enum CursorMode CursorMode() const override
    {
        return static_cast<enum CursorMode>(GlobalConfig().GetInt(g_ConfigCursorMode));
    }
    [[nodiscard]] bool HideScrollbar() const override { return GlobalConfig().GetBool(g_ConfigHideScrollbar); }
};

std::shared_ptr<Settings> TerminalSettings()
{
    [[clang::no_destroy]] static const auto settings = std::make_shared<SettingsImpl>();
    return settings;
}

} // namespace nc::term
