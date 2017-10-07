#include "SettingsAdaptor.h"
#include <Term/Settings.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Bootstrap/Config.h>

namespace nc::term {

static const auto g_ConfigMaxFPS = "terminal.maxFPS";
static const auto g_ConfigCursorMode = "terminal.cursorMode";
    
class SettingsImpl : public Settings
{
public:
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
};
    
shared_ptr<Settings> TerminalSettings()
{
    const auto settings = make_shared<SettingsImpl>();
    return settings;
}

}
