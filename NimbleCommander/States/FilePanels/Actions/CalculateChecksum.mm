// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/GeneralUI/CalculateChecksumSheetController.h>
#include "../PanelController.h"
#include "CalculateChecksum.h"
#include "../PanelData.h"
#include "../PanelView.h"

namespace nc::panel::actions {

bool CalculateChecksum::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
        return false;

    auto i = _target.view.item;
    return i && (!i.IsDir() || _target.data.Stats().selected_entries_amount > 0);
}

void CalculateChecksum::Perform( PanelController *_target, id _sender ) const
{
    vector<string> filenames;
    vector<uint64_t> sizes;
    
    auto selected_entries = _target.selectedEntriesOrFocusedEntry;
    for( auto &i: selected_entries )
        if( i.IsReg() && !i.IsSymlink() ) {
            filenames.emplace_back( i.Filename() );
            sizes.emplace_back( i.Size() );
        }

    if( filenames.empty() )
        return;
    
    CalculateChecksumSheetController *sheet = [CalculateChecksumSheetController alloc];
    sheet = [sheet initWithFiles:move(filenames)
                       withSizes:move(sizes)
                          atHost:_target.vfs
                          atPath:_target.currentDirectoryPath];
    
    [sheet beginSheetForWindow:_target.window
             completionHandler:^(NSModalResponse returnCode) {
                 if(sheet.didSaved) {
                     DelayedFocusing req;
                     req.filename = sheet.savedFilename;
                     [_target scheduleDelayedFocusing:req];
                 }
             }];
}

};
