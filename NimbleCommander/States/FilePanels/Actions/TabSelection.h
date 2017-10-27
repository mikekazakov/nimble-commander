// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class MainWindowFilePanelState;

namespace nc::panel::actions {

struct ShowNextTab
{
    static bool Predicate( MainWindowFilePanelState *_target );
    static bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item );
    static void Perform( MainWindowFilePanelState *_target, id _sender );
};

struct ShowPreviousTab
{
    static bool Predicate( MainWindowFilePanelState *_target );
    static bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item );
    static void Perform( MainWindowFilePanelState *_target, id _sender );
};

}
