// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OpenFile.h"
#include "../NCPanelOpenWithMenuDelegate.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include "../PanelAux.h"
#include <VFS/VFS.h>
#include <Utility/ObjCpp.h>

namespace nc::panel::actions {

static void PerformOpeningFilesWithDefaultHandler(const std::vector<VFSListingItem>& _items,
                                                  PanelController* _target,
                                                  FileOpener &_file_opener);

static bool CommonPredicate( PanelController *_target )
{
    auto i = _target.view.item;
    if( !i )
        return false;
    
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

static bool ShouldRebuildSubmenu(NSMenuItem *_item) noexcept
{
    return _item.hasSubmenu == false ||
        objc_cast<NCPanelOpenWithMenuDelegate>(_item.submenu.delegate) == nil;    
}
    
OpenFileWithSubmenu::OpenFileWithSubmenu(NCPanelOpenWithMenuDelegate *_menu_delegate):
    m_MenuDelegate(_menu_delegate)
{
}

bool OpenFileWithSubmenu::Predicate( PanelController *_target ) const
{
    return CommonPredicate(_target);
}

bool OpenFileWithSubmenu::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if( ShouldRebuildSubmenu(_item) ) {
        NSMenu *menu = [[NSMenu alloc] init];
        menu.identifier = NCPanelOpenWithMenuDelegate.regularMenuIdentifier;
        menu.delegate = m_MenuDelegate;
        [m_MenuDelegate addManagedMenu:menu];
        _item.submenu = menu;
    }
    
    m_MenuDelegate.target = _target;

    return Predicate(_target);
}

AlwaysOpenFileWithSubmenu::AlwaysOpenFileWithSubmenu(NCPanelOpenWithMenuDelegate *_menu_delegate):
    m_MenuDelegate(_menu_delegate)
{
}
    
bool AlwaysOpenFileWithSubmenu::Predicate( PanelController *_target ) const
{
    return CommonPredicate(_target);
}

bool AlwaysOpenFileWithSubmenu::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )const
{
    if( ShouldRebuildSubmenu(_item) ) {
        NSMenu *menu = [[NSMenu alloc] init];
        menu.identifier = NCPanelOpenWithMenuDelegate.alwaysOpenWithMenuIdentifier;
        menu.delegate = m_MenuDelegate;
        [m_MenuDelegate addManagedMenu:menu];
        _item.submenu = menu;
    }
    
    m_MenuDelegate.target = _target;

    return Predicate(_target);
}

OpenFilesWithDefaultHandler::OpenFilesWithDefaultHandler(FileOpener &_file_opener):
    m_FileOpener(_file_opener)
{
}
    
bool OpenFilesWithDefaultHandler::Predicate( PanelController *_target ) const
{
    return (bool)_target.view.item;
}

void OpenFilesWithDefaultHandler::Perform( PanelController *_target, id ) const
{
    if( !Predicate(_target) ) {
        NSBeep();
        return;
    }

    auto entries = _target.selectedEntriesOrFocusedEntryWithDotDot;
    PerformOpeningFilesWithDefaultHandler(entries, _target, m_FileOpener);
}

static void PerformOpeningFilesWithDefaultHandler(const std::vector<VFSListingItem>& _items,
                                                  PanelController* _target,
                                                  FileOpener &_file_opener)
{
    if( _items.empty() )
        return;
    
    if( _items.size() > 1 ) {
        const auto same_host = all_of( begin(_items), end(_items), [&](const auto &i){
            return i.Host() == _items.front().Host();
          });
        if( same_host ) {
            std::vector<std::string> items;
            for(auto &i: _items)
                items.emplace_back( i.Path() );
            _file_opener.Open(items, _items.front().Host(), nil, _target);
        }
    }
    else if( _items.size() == 1 ) {
        auto &item = _items.front();
        std::string path = item.IsDotDot() ? item.Directory() : item.Path();
        _file_opener.Open(path, item.Host(), _target);
    }
}

context::OpenFileWithDefaultHandler::
    OpenFileWithDefaultHandler(const std::vector<VFSListingItem>& _items,
                               FileOpener &_file_opener):
        m_Items(_items),
        m_FileOpener(_file_opener)
{
}

bool context::OpenFileWithDefaultHandler::
Predicate( [[maybe_unused]] PanelController *_target ) const
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

void context::OpenFileWithDefaultHandler::Perform( PanelController *_target, id ) const
{
    PerformOpeningFilesWithDefaultHandler(m_Items, _target, m_FileOpener);
}

}
