#include "../PanelController.h"
#include "RenameInPlace.h"
#include "../PanelView.h"

namespace panel::actions {

bool RenameInPlace::Predicate( PanelController *_target ) const
{
    const auto item = _target.view.item;
    return item && !item.IsDotDot() && item.Host()->IsWritable();
}

void RenameInPlace::Perform( PanelController *_target, id _sender ) const
{
    [_target.view startFieldEditorRenaming];
}

}
