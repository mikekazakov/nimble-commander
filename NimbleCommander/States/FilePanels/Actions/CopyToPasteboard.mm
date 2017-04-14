#include "CopyToPasteboard.h"
#include "../PanelController.h"
#include "../Helpers/Pasteboard.h"

namespace panel::actions {

bool CopyToPasteboard::Predicate( PanelController *_target ) const
{
    return _target.view.item;
}

void CopyToPasteboard::Perform( PanelController *_target, id _sender ) const
{
    panel::PasteboardSupport::WriteFilesnamesPBoard(_target.selectedEntriesOrFocusedEntryWithDotDot,
                                                    NSPasteboard.generalPasteboard);
}

}
