// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ToggleSort.h"
#include "../PanelController.h"
#include "../PanelData.h"

namespace nc::panel::actions {

static const auto g_SortAscImage = [NSImage imageNamed:@"NSAscendingSortIndicator"];
static const auto g_SortDescImage = [NSImage imageNamed:@"NSDescendingSortIndicator"];

static NSImage *ImageFromSortMode( data::SortMode::Mode _mode )
{
    switch( _mode ) {
        case data::SortMode::SortByName:         return g_SortAscImage;
        case data::SortMode::SortByNameRev:      return g_SortDescImage;
        case data::SortMode::SortByExt:          return g_SortAscImage;
        case data::SortMode::SortByExtRev:       return g_SortDescImage;
        case data::SortMode::SortBySize:         return g_SortDescImage;
        case data::SortMode::SortBySizeRev:      return g_SortAscImage;
        case data::SortMode::SortByBirthTime:    return g_SortDescImage;
        case data::SortMode::SortByBirthTimeRev: return g_SortAscImage;
        case data::SortMode::SortByModTime:      return g_SortDescImage;
        case data::SortMode::SortByModTimeRev:   return g_SortAscImage;
        case data::SortMode::SortByAddTime:      return g_SortDescImage;
        case data::SortMode::SortByAddTimeRev:   return g_SortAscImage;
        default: return nil;
    }
}

static void UpdateItemState(NSMenuItem *_item,
                            data::SortMode _mode,
                            data::SortMode::Mode _direct,
                            data::SortMode::Mode _reversed)
{
    if( _mode.sort == _direct || _mode.sort == _reversed ) {
        _item.image = ImageFromSortMode( _mode.sort );
        _item.state = NSOnState;
    }
    else {
        _item.image = nil;
        _item.state = NSOffState;
    }
}

    static data::SortMode EnforceAndSwitch(data::SortMode _mode,
                                           data::SortMode::Mode _direct,
                                           data::SortMode::Mode _reversed)
{
    _mode.sort = (_mode.sort != _direct ? _direct : _reversed);
    return _mode;
}

bool ToggleSortingByName::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )  const
{
    UpdateItemState(_item,
                    _target.data.SortMode(),
                    data::SortMode::SortByName,
                    data::SortMode::SortByNameRev );
    return Predicate( _target );
}

void ToggleSortingByName::Perform( PanelController *_target, id _sender ) const
{
    [_target changeSortingModeTo:EnforceAndSwitch(_target.data.SortMode(),
                                                  data::SortMode::SortByName,
                                                  data::SortMode::SortByNameRev)];
}

bool ToggleSortingByExtension::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    UpdateItemState(_item,
                    _target.data.SortMode(),
                    data::SortMode::SortByExt,
                    data::SortMode::SortByExtRev );
    return Predicate( _target );
}

void ToggleSortingByExtension::Perform( PanelController *_target, id _sender ) const
{
    [_target changeSortingModeTo:EnforceAndSwitch(_target.data.SortMode(),
                                                  data::SortMode::SortByExt,
                                                  data::SortMode::SortByExtRev)];
}

bool ToggleSortingBySize::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    UpdateItemState(_item,
                    _target.data.SortMode(),
                    data::SortMode::SortBySize,
                    data::SortMode::SortBySizeRev );
    return Predicate( _target );
}

void ToggleSortingBySize::Perform( PanelController *_target, id _sender ) const
{
    [_target changeSortingModeTo:EnforceAndSwitch(_target.data.SortMode(),
                                                  data::SortMode::SortBySize,
                                                  data::SortMode::SortBySizeRev)];
}

bool ToggleSortingByModifiedTime::ValidateMenuItem(PanelController *_target, NSMenuItem *_item)const
{
    UpdateItemState(_item,
                    _target.data.SortMode(),
                    data::SortMode::SortByModTime,
                    data::SortMode::SortByModTimeRev );
    return Predicate( _target );
}

void ToggleSortingByModifiedTime::Perform( PanelController *_target, id _sender ) const
{
    [_target changeSortingModeTo:EnforceAndSwitch(_target.data.SortMode(),
                                                  data::SortMode::SortByModTime,
                                                  data::SortMode::SortByModTimeRev)];
}

bool ToggleSortingByCreatedTime::ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const
{
    UpdateItemState(_item,
                    _target.data.SortMode(),
                    data::SortMode::SortByBirthTime,
                    data::SortMode::SortByBirthTimeRev );
    return Predicate( _target );
}

void ToggleSortingByCreatedTime::Perform( PanelController *_target, id _sender ) const
{
    [_target changeSortingModeTo:EnforceAndSwitch(_target.data.SortMode(),
                                                  data::SortMode::SortByBirthTime,
                                                  data::SortMode::SortByBirthTimeRev)];
}

bool ToggleSortingByAddedTime::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    UpdateItemState(_item,
                    _target.data.SortMode(),
                    data::SortMode::SortByAddTime,
                    data::SortMode::SortByAddTimeRev );
    return Predicate( _target );
}

void ToggleSortingByAddedTime::Perform( PanelController *_target, id _sender ) const
{
    [_target changeSortingModeTo:EnforceAndSwitch(_target.data.SortMode(),
                                                  data::SortMode::SortByAddTime,
                                                  data::SortMode::SortByAddTimeRev)];
}

bool ToggleSortingCaseSensitivity::ValidateMenuItem(PanelController *_target,NSMenuItem *_item)const
{
    _item.state = _target.data.SortMode().case_sens;
    return Predicate( _target );
}

void ToggleSortingCaseSensitivity::Perform( PanelController *_target, id _sender ) const
{
    auto mode = _target.data.SortMode();
    mode.case_sens = !mode.case_sens;
    [_target changeSortingModeTo:mode];
}

bool ToggleSortingFoldersSeparation::ValidateMenuItem(PanelController *_target,
                                                      NSMenuItem *_item ) const
{
    _item.state = _target.data.SortMode().sep_dirs;
    return Predicate( _target );
}

void ToggleSortingFoldersSeparation::Perform( PanelController *_target, id _sender ) const
{
    auto mode = _target.data.SortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [_target changeSortingModeTo:mode];
}

bool ToggleSortingExtensionlessFolders::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    _item.state = _target.data.SortMode().extensionless_dirs;
    return Predicate( _target );
}

void ToggleSortingExtensionlessFolders::Perform( PanelController *_target, id _sender ) const
{
    auto mode = _target.data.SortMode();
    mode.extensionless_dirs = !mode.extensionless_dirs;
    [_target changeSortingModeTo:mode];
}

bool ToggleSortingNumerical::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    _item.state = _target.data.SortMode().numeric_sort;
    return Predicate( _target );
}

void ToggleSortingNumerical::Perform( PanelController *_target, id _sender ) const
{
    auto mode = _target.data.SortMode();
    mode.numeric_sort = !mode.numeric_sort;
    [_target changeSortingModeTo:mode];
}

bool ToggleSortingShowHidden::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    _item.state = _target.data.HardFiltering().show_hidden;
    return Predicate( _target );
}

void ToggleSortingShowHidden::Perform( PanelController *_target, id _sender ) const
{
    auto filtering = _target.data.HardFiltering();
    filtering.show_hidden = !filtering.show_hidden;
    [_target changeHardFilteringTo:filtering];
}

};
