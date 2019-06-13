// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/Config.h>
#include "../PanelController.h"
#include "../PanelView.h"
#include "CopyFilePaths.h"
#include <VFS/VFS.h>
#include <Utility/StringExtras.h>
#include <numeric>

namespace nc::panel::actions {

static const char* Separator()
{
    static const auto config_path = "filePanel.general.separatorForCopyingMultipleFilenames";
    static const auto s = GlobalConfig().GetString(config_path);
    return s.c_str();
}

static void WriteSingleStringToClipboard(const std::string &_s)
{
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb declareTypes:@[NSStringPboardType]
               owner:nil];
    [pb setString:[NSString stringWithUTF8StdString:_s]
          forType:NSStringPboardType];
}

bool CopyFileName::Predicate( PanelController *_source ) const
{
    return _source.view.item;
}

bool CopyFilePath::Predicate( PanelController *_source ) const
{
    return _source.view.item;
}
    
bool CopyFileDirectory::Predicate( PanelController *_source ) const
{
    return _source.view.item;
}

void CopyFileName::Perform( PanelController *_source, id ) const
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    const auto result = std::accumulate(std::begin(entries),
                                        std::end(entries),
                                        std::string{},
                                        [](auto &a, auto &b){
        return a + (a.empty() ? "" : Separator()) + b.Filename();
    });
    WriteSingleStringToClipboard( result );
}

void CopyFilePath::Perform( PanelController *_source, id ) const
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    const auto result = std::accumulate(std::begin(entries),
                                        std::end(entries),
                                        std::string{},
                                        [](auto &a, auto &b){
        return a + (a.empty() ? "" : Separator()) + b.Path();
    });
    WriteSingleStringToClipboard( result );
}
    
void CopyFileDirectory::Perform( PanelController *_source, id ) const
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    const auto result = std::accumulate(std::begin(entries),
                                        std::end(entries),
                                        std::string{},
                                        [](auto &a, auto &b){
        return a + (a.empty() ? "" : Separator()) + b.Directory();
    });
    WriteSingleStringToClipboard( result );
}
    
}
