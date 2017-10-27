// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OpenFile.h"
#include "../NCPanelOpenWithMenuDelegate.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include "../PanelAux.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

static NCPanelOpenWithMenuDelegate *Delegate()
{
    static NCPanelOpenWithMenuDelegate *instance = [[NCPanelOpenWithMenuDelegate alloc] init];
    return instance;
}

static void PerformOpeningFilesWithDefaultHandler(const vector<VFSListingItem>& _items,
                                                  PanelController* _target);

static bool CommonPredicate( PanelController *_target )
{
    auto i = _target.view.item;
    if( !i )
        return false;
    
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

bool OpenFileWithSubmenu::Predicate( PanelController *_target ) const
{
    return CommonPredicate(_target);
}

bool OpenFileWithSubmenu::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if( !_item.hasSubmenu ) {
        NSMenu *menu = [[NSMenu alloc] init];
        menu.identifier = NCPanelOpenWithMenuDelegate.regularMenuIdentifier;
        menu.delegate = Delegate();
        [Delegate() addManagedMenu:menu];
        _item.submenu = menu;
    }
    
    Delegate().target = _target;

    return Predicate(_target);
}

bool AlwaysOpenFileWithSubmenu::Predicate( PanelController *_target ) const
{
    return CommonPredicate(_target);
}

bool AlwaysOpenFileWithSubmenu::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if( !_item.hasSubmenu ) {
        NSMenu *menu = [[NSMenu alloc] init];
        menu.identifier = NCPanelOpenWithMenuDelegate.alwaysOpenWithMenuIdentifier;
        menu.delegate = Delegate();
        [Delegate() addManagedMenu:menu];
        _item.submenu = menu;
    }
    
    Delegate().target = _target;

    return Predicate(_target);
}

bool OpenFilesWithDefaultHandler::Predicate( PanelController *_target ) const
{
    return (bool)_target.view.item;
}

void OpenFilesWithDefaultHandler::Perform( PanelController *_target, id _sender ) const
{
    if( !Predicate(_target) ) {
        NSBeep();
        return;
    }

    auto entries = _target.selectedEntriesOrFocusedEntryWithDotDot;
    PerformOpeningFilesWithDefaultHandler(entries, _target);
}

bool OpenFocusedFileWithDefaultHandler::Predicate( PanelController *_target ) const
{
    return (bool)_target.view.item;
}

void OpenFocusedFileWithDefaultHandler::Perform( PanelController *_target, id _sender ) const
{
    if( !Predicate(_target) ) {
        NSBeep();
        return;
    }

    auto entries = vector<VFSListingItem>{1, _target.view.item};
    PerformOpeningFilesWithDefaultHandler(entries, _target);
}

static void PerformOpeningFilesWithDefaultHandler(const vector<VFSListingItem>& _items,
                                                  PanelController* _target)
{
    if( _items.empty() )
        return;
    
    if( _items.size() > 1 ) {
        const auto same_host = all_of( begin(_items), end(_items), [&](const auto &i){
            return i.Host() == _items.front().Host();
          });
        if( same_host ) {
            vector<string> items;
            for(auto &i: _items)
                items.emplace_back( i.Path() );
            PanelVFSFileWorkspaceOpener::Open(items,
                                              _items.front().Host(),
                                              nil,
                                              _target);
        }
    }
    else if( _items.size() == 1 ) {
        auto &item = _items.front();
        string path = item.IsDotDot() ? item.Directory() : item.Path();
        PanelVFSFileWorkspaceOpener::Open(path, item.Host(), _target);
    }
}

context::OpenFileWithDefaultHandler::
    OpenFileWithDefaultHandler(const vector<VFSListingItem>& _items):
        m_Items(_items)
{
}

bool context::OpenFileWithDefaultHandler::Predicate( PanelController *_target ) const
{
    const auto has_reg_files = any_of(begin(m_Items),
                                      end(m_Items),
                                      [](auto &_i){ return _i.IsReg(); });
    if( has_reg_files )
        return true;
    
    const auto all_are_native = all_of(begin(m_Items),
                                       end(m_Items),
                                       [](auto &_i){ return _i.Host()->IsNativeFS(); });
    return all_are_native;
}

void context::OpenFileWithDefaultHandler::Perform( PanelController *_target, id _sender ) const
{
    PerformOpeningFilesWithDefaultHandler(m_Items, _target);
}

}
