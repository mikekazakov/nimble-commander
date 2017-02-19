#include "../MainWindowFilePanelState.h"
#include "TabSelection.h"

namespace panels::actions {

bool ShowNextTab::Predicate( MainWindowFilePanelState *_target )
{
    return _target.currentSideTabsCount > 1;
}

bool ShowNextTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void ShowNextTab::Perform( MainWindowFilePanelState *_target, id _sender )
{
    [_target selectNextFilePanelTab];
}

bool ShowPreviousTab::Predicate( MainWindowFilePanelState *_target )
{
    return _target.currentSideTabsCount > 1;
}

bool ShowPreviousTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void ShowPreviousTab::Perform( MainWindowFilePanelState *_target, id _sender )
{
    [_target selectPreviousFilePanelTab];
}

}
