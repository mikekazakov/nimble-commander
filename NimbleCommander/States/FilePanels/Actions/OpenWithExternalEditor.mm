#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "../PanelView.h"
#include "../PanelController.h"
#include "../ExternalEditorInfo.h"
#include "../PanelAux.h"
#include "OpenWithExternalEditor.h"

namespace panel::actions {

bool OpenWithExternalEditor::Predicate( PanelController *_target )
{
    auto i = _target.view.item;
    return i && !i.IsDotDot();
}

void OpenWithExternalEditor::Perform( PanelController *_target, id _sender )
{
    auto item = _target.view.item;
    if( !item || item.IsDotDot() )
        return;
    
    auto ed = AppDelegate.me.externalEditorsStorage.ViableEditorForItem(item);
    if( !ed ) {
        NSBeep();
        return;
    }
    
    if( ed->OpenInTerminal() == false )
        PanelVFSFileWorkspaceOpener::Open(item.Path(),
                                          item.Host(),
                                          ed->Path(),
                                          _target);
    else
        PanelVFSFileWorkspaceOpener::OpenInExternalEditorTerminal(item.Path(),
                                                                  item.Host(),
                                                                  ed,
                                                                  item.Filename(),
                                                                  _target);
}

};
