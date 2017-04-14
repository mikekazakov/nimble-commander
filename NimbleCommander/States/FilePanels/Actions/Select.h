#pragma once

#include "DefaultAction.h"

namespace panel::actions {

struct SelectAll : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct DeselectAll : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct InvertSelection : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct SelectAllByExtension : PanelAction
{
    SelectAllByExtension( bool _result_selection );
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    bool m_ResultSelection;
};

};
