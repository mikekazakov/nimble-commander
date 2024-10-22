// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CopyFile.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include <Panel/PanelData.h>
#include <Panel/PanelDataStatistics.h>
#include "../PanelView.h"
#include "../PanelAux.h"
#include "Helpers.h"
#include <Operations/Copying.h>
#include <Operations/CopyingDialog.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <Base/dispatch_cpp.h>
#include <Config/Config.h>

namespace nc::panel::actions {

static std::function<void()> RefreshCurrentActiveControllerLambda(MainWindowFilePanelState *_target);
static std::function<void()> RefreshBothCurrentControllersLambda(MainWindowFilePanelState *_target);

static const auto g_DeselectConfigFlag = "filePanel.general.deselectItemsAfterFileOperations";

CopyBase::CopyBase(nc::config::Config &_config) : m_Config(_config)
{
}

void CopyBase::AddDeselectorIfNeeded(nc::ops::Operation &_operation, PanelController *_target) const
{
    if( !ShouldAutomaticallyDeselect() )
        return;

    const auto deselector = std::make_shared<const DeselectorViaOpNotification>(_target);
    _operation.SetItemStatusCallback([deselector](nc::ops::ItemStateReport _report) { deselector->Handle(_report); });
}

bool CopyBase::ShouldAutomaticallyDeselect() const
{
    return m_Config.GetBool(g_DeselectConfigFlag);
}

CopyTo::CopyTo(nc::config::Config &_config) : CopyBase(_config)
{
}

bool CopyTo::Predicate(MainWindowFilePanelState *_target) const
{
    const auto act_pc = _target.activePanelController;
    const auto opp_pc = _target.self.oppositePanelController;
    if( !act_pc || !opp_pc )
        return false;

    const auto i = act_pc.view.item;
    if( !i )
        return false;

    if( i.IsDotDot() && act_pc.data.Stats().selected_entries_amount == 0 )
        return false;

    if( opp_pc.isUniform && !opp_pc.vfs->IsWritable() )
        return false;

    return true;
}

void CopyTo::Perform(MainWindowFilePanelState *_target, id /*_sender*/) const
{
    const auto act_pc = _target.activePanelController;
    const auto opp_pc = _target.oppositePanelController;
    if( !act_pc || !opp_pc )
        return;

    auto entries = _target.activePanelController.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;

    const auto act_uniform = act_pc.isUniform;
    const auto opp_uniform = opp_pc.isUniform;

    const auto cd = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                                    sourceVFS:act_uniform ? act_pc.vfs : nullptr
                                              sourceDirectory:act_uniform ? act_pc.currentDirectoryPath : ""
                                           initialDestination:opp_uniform ? opp_pc.currentDirectoryPath : ""
                                               destinationVFS:opp_uniform ? opp_pc.vfs : nullptr
                                             operationOptions:MakeDefaultFileCopyOptions()];

    const auto handler = ^(NSModalResponse returnCode) {
      if( returnCode != NSModalResponseOK )
          return;

      auto path = cd.resultDestination;
      auto host = cd.resultHost;
      auto opts = cd.resultOptions;
      if( !host || path.empty() )
          return; // ui invariant is broken

      const auto op = std::make_shared<nc::ops::Copying>(entries, path, host, opts);

      const auto update_both_panels = RefreshBothCurrentControllersLambda(_target);
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update_both_panels);

      AddDeselectorIfNeeded(*op, act_pc);

      [_target.mainWindowController enqueueOperation:op];
    };

    [_target.mainWindowController beginSheet:cd.window completionHandler:handler];
}

CopyAs::CopyAs(nc::config::Config &_config) : CopyBase(_config)
{
}

bool CopyAs::Predicate(MainWindowFilePanelState *_target) const
{
    const auto act_pc = _target.activePanelController;
    if( !act_pc )
        return false;

    const auto i = act_pc.view.item;
    if( !i || i.IsDotDot() )
        return false;

    if( !i.Host()->IsWritable() )
        return false;

    return true;
}

void CopyAs::Perform(MainWindowFilePanelState *_target, id /*_sender*/) const
{
    const auto act_pc = _target.activePanelController;
    if( !act_pc )
        return;

    // process only currently focused item
    const auto item = act_pc.view.item;
    if( !item || item.IsDotDot() )
        return;

    const auto entries = std::vector<VFSListingItem>({item});

    const auto cd = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                                    sourceVFS:item.Host()
                                              sourceDirectory:item.Directory()
                                           initialDestination:item.Filename()
                                               destinationVFS:item.Host()
                                             operationOptions:MakeDefaultFileCopyOptions()];

    const auto handler = ^(NSModalResponse returnCode) {
      if( returnCode != NSModalResponseOK )
          return;

      auto path = cd.resultDestination;
      auto host = cd.resultHost;
      auto opts = cd.resultOptions;
      if( !host || path.empty() )
          return; // ui invariant is broken

      const auto op = std::make_shared<nc::ops::Copying>(entries, path, host, opts);

      const auto update = RefreshCurrentActiveControllerLambda(_target);
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update);

      __weak PanelController *weak_panel = act_pc;
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
          dispatch_to_main_queue([=] {
              if( PanelController *const panel = weak_panel ) {
                  if( panel.isUniform &&
                      panel.currentDirectoryPath == std::filesystem::path(path).parent_path().native() + "/" ) {
                      nc::panel::DelayedFocusing req;
                      req.filename = std::filesystem::path(path).filename().native();
                      [panel scheduleDelayedFocusing:req];
                  }
              }
          });
      });

      AddDeselectorIfNeeded(*op, act_pc);

      [_target.mainWindowController enqueueOperation:op];
    };

    [_target.mainWindowController beginSheet:cd.window completionHandler:handler];
}

bool MoveTo::Predicate(MainWindowFilePanelState *_target) const
{
    const auto act_pc = _target.activePanelController;
    const auto opp_pc = _target.self.oppositePanelController;
    if( !act_pc || !opp_pc )
        return false;

    const auto i = act_pc.view.item;
    if( !i )
        return false;

    if( i.IsDotDot() && act_pc.data.Stats().selected_entries_amount == 0 )
        return false;

    if( (act_pc.isUniform && !act_pc.vfs->IsWritable()) || (opp_pc.isUniform && !opp_pc.vfs->IsWritable()) )
        return false;

    return true;
}

void MoveTo::Perform(MainWindowFilePanelState *_target, id /*_sender*/) const
{
    const auto act_pc = _target.activePanelController;
    const auto opp_pc = _target.oppositePanelController;
    if( !act_pc || !opp_pc )
        return;

    const auto act_uniform = act_pc.isUniform;
    const auto opp_uniform = opp_pc.isUniform;

    if( act_uniform && !act_pc.vfs->IsWritable() )
        return;

    auto entries = act_pc.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;

    const auto cd = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                                    sourceVFS:act_uniform ? act_pc.vfs : nullptr
                                              sourceDirectory:act_uniform ? act_pc.currentDirectoryPath : ""
                                           initialDestination:opp_uniform ? opp_pc.currentDirectoryPath : ""
                                               destinationVFS:opp_uniform ? opp_pc.vfs : nullptr
                                             operationOptions:MakeDefaultFileMoveOptions()];

    const auto handler = ^(NSModalResponse returnCode) {
      if( returnCode != NSModalResponseOK )
          return;

      auto path = cd.resultDestination;
      auto host = cd.resultHost;
      auto opts = cd.resultOptions;
      if( !host || path.empty() )
          return; // ui invariant is broken

      const auto op = std::make_shared<nc::ops::Copying>(entries, path, host, opts);

      const auto update_both_panels = RefreshBothCurrentControllersLambda(_target);
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update_both_panels);

      [_target.mainWindowController enqueueOperation:op];
    };

    [_target.mainWindowController beginSheet:cd.window completionHandler:handler];
}

bool MoveAs::Predicate(MainWindowFilePanelState *_target) const
{
    const auto act_pc = _target.activePanelController;
    if( !act_pc )
        return false;

    const auto i = act_pc.view.item;
    if( !i || i.IsDotDot() )
        return false;

    if( !i.Host()->IsWritable() )
        return false;

    return true;
}

void MoveAs::Perform(MainWindowFilePanelState *_target, id /*_sender*/) const
{
    const auto act_pc = _target.activePanelController;
    if( !act_pc )
        return;

    // process only current cursor item
    const auto item = act_pc.view.item;
    if( !item || item.IsDotDot() || !item.Host()->IsWritable() )
        return;

    const auto entries = std::vector<VFSListingItem>({item});

    const auto cd = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                                    sourceVFS:item.Host()
                                              sourceDirectory:item.Directory()
                                           initialDestination:item.Filename()
                                               destinationVFS:item.Host()
                                             operationOptions:MakeDefaultFileMoveOptions()];

    const auto handler = ^(NSModalResponse returnCode) {
      if( returnCode != NSModalResponseOK )
          return;

      auto path = cd.resultDestination;
      auto host = cd.resultHost;
      auto opts = cd.resultOptions;
      if( !host || path.empty() )
          return; // ui invariant is broken

      const auto op = std::make_shared<nc::ops::Copying>(entries, path, host, opts);

      const auto update = RefreshCurrentActiveControllerLambda(_target);
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update);

      __weak auto cur = act_pc;
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
          dispatch_to_main_queue([=] {
              nc::panel::DelayedFocusing req;
              req.filename = std::filesystem::path(path).filename().native();
              [static_cast<PanelController *>(cur) scheduleDelayedFocusing:req];
          });
      });

      [_target.mainWindowController enqueueOperation:op];
    };

    [_target.mainWindowController beginSheet:cd.window completionHandler:handler];
}

static std::function<void()> RefreshCurrentActiveControllerLambda(MainWindowFilePanelState *_target)
{
    __weak PanelController *cur = _target.activePanelController;
    auto update_current = [=] { dispatch_to_main_queue([=] { [static_cast<PanelController *>(cur) refreshPanel]; }); };
    return update_current;
}

static std::function<void()> RefreshBothCurrentControllersLambda(MainWindowFilePanelState *_target)
{
    __weak PanelController *cur = _target.activePanelController;
    __weak PanelController *opp = _target.oppositePanelController;
    auto update_both_panels = [=] {
        dispatch_to_main_queue([=] {
            [static_cast<PanelController *>(cur) refreshPanel];
            [static_cast<PanelController *>(opp) refreshPanel];
        });
    };
    return update_both_panels;
}

} // namespace nc::panel::actions
