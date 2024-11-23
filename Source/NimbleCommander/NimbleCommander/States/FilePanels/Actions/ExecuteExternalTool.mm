// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExecuteExternalTool.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../MainWindowFilePanelState.h"
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include <NimbleCommander/Core/Alert.h>
#include <Panel/ExternalTools.h>
#include "../ExternalToolParameterValueSheetController.h"
#include <Utility/ObjCpp.h>
#include <Base/debug.h>

namespace nc::panel::actions {

struct ExecuteExternalTool::Payload {
    Payload(const ExternalTool &_tool, const ExternalToolExecution::Context &_ctx, MainWindowFilePanelState *_target);
    ExternalTool tool;
    ExternalToolExecution exec;
    MainWindowFilePanelState *target;
};

ExecuteExternalTool::Payload::Payload(const ExternalTool &_tool,
                                      const ExternalToolExecution::Context &_ctx,
                                      MainWindowFilePanelState *_target)
    : tool(_tool), exec(_ctx, tool), target(_target)
{
}

ExecuteExternalTool::ExecuteExternalTool(nc::utility::TemporaryFileStorage &_temp_storage)
    : m_TempFileStorage{_temp_storage}
{
}

void ExecuteExternalTool::Perform(MainWindowFilePanelState *_target, id _sender) const
{
    if( [_sender respondsToSelector:@selector(representedObject)] ) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-selector-match"
        const id rep_obj = [_sender representedObject];
#pragma clang diagnostic pop
        if( auto any_holder = objc_cast<AnyHolder>(rep_obj) )
            if( auto tool = std::any_cast<std::shared_ptr<const ExternalTool>>(&any_holder.any) )
                if( tool->get() )
                    Execute(*tool->get(), _target);
    }
}

void ExecuteExternalTool::Execute(const ExternalTool &_tool, MainWindowFilePanelState *_target) const
{
    dispatch_assert_main_queue();

    // do nothing for invalid tools
    if( _tool.m_ExecutablePath.empty() )
        return;

    ExternalToolExecution::Context ctx;
    ctx.left_data = &_target.leftPanelController.data;
    ctx.left_cursor_pos = _target.leftPanelController.view.curpos;
    ctx.right_data = &_target.rightPanelController.data;
    ctx.right_cursor_pos = _target.rightPanelController.view.curpos;
    ctx.focus = _target.activePanelController == _target.leftPanelController ? ExternalToolExecution::PanelFocus::left
                                                                             : ExternalToolExecution::PanelFocus::right;
    ctx.temp_storage = &m_TempFileStorage;
    auto payload = std::make_shared<Payload>(_tool, ctx, _target);

    if( payload->exec.RequiresUserInput() ) {
        auto prompts = payload->exec.UserInputPrompts();

        auto sheet = [[ExternalToolParameterValueSheetController alloc]
            initWithValueNames:std::vector<std::string>{prompts.begin(), prompts.end()}
                      toolName:_tool.m_Title];
        [sheet beginSheetForWindow:_target.window
                 completionHandler:^(NSModalResponse returnCode) {
                   if( returnCode == NSModalResponseOK ) {
                       payload->exec.CommitUserInput(sheet.values);
                       RunExtTool(payload);
                   }
                 }];
    }
    else {
        RunExtTool(payload);
    }
}

void ExecuteExternalTool::RunExtTool(std::shared_ptr<Payload> _payload)
{
    assert(_payload);
    dispatch_assert_main_queue();

    const auto startup_mode = _payload->exec.DeduceStartupMode();
    if( startup_mode == ExternalTool::StartupMode::RunInTerminal ) {
        // TODO: error handling
        if( base::AmISandboxed() )
            return;
        const auto path = _payload->exec.ExecutablePath();
        const auto args = _payload->exec.BuildArguments();
        if( auto ctrl = objc_cast<NCMainWindowController>(_payload->target.window.delegate) )
            [ctrl requestTerminalExecutionWithFullPath:path andArguments:args];
    }
    else if( startup_mode == ExternalTool::StartupMode::RunDeatached ) {
        const std::expected<pid_t, std::string> result = _payload->exec.StartDetached();
        if( !result.has_value() ) {
            Alert *const alert = [[Alert alloc] init];
            alert.alertStyle = NSAlertStyleWarning;
            alert.messageText =
                [NSString localizedStringWithFormat:NSLocalizedString(
                                                        @"Unable to run the external tool \"%s\"",
                                                        "Message text alerting the inability to run an external tool"),
                                                    _payload->tool.m_Title.c_str()];
            alert.informativeText = [NSString stringWithUTF8String:result.error().c_str()];
            [alert runModal];
        }
    }
}

} // namespace nc::panel::actions
