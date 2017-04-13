#include <NimbleCommander/Bootstrap/Config.h>
#include "../PanelController.h"
#include "../PanelView.h"
#include "CopyFilePaths.h"

namespace panel::actions {

static const char* Separator()
{
    static const auto config_path = "filePanel.general.separatorForCopyingMultipleFilenames";
    static const auto s = *GlobalConfig().GetString(config_path);
    return s.c_str();
}

static void WriteSingleStringToClipboard(const string &_s)
{
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb declareTypes:@[NSStringPboardType]
               owner:nil];
    [pb setString:[NSString stringWithUTF8StdString:_s]
          forType:NSStringPboardType];
}

bool CopyFileName::Predicate( PanelController *_source )
{
    return _source.view.item;
}

bool CopyFilePath::Predicate( PanelController *_source )
{
    return _source.view.item;
}

void CopyFileName::Perform( PanelController *_source, id _sender )
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    const auto result = accumulate( begin(entries), end(entries), string{}, [](auto &a, auto &b){
        return a + (a.empty() ? "" : Separator()) + b.Filename();
    });
    WriteSingleStringToClipboard( result );
}

void CopyFilePath::Perform( PanelController *_source, id _sender )
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    const auto result = accumulate( begin(entries), end(entries), string{}, [](auto &a, auto &b){
        return a + (a.empty() ? "" : Separator()) + b.Path();
    });
    WriteSingleStringToClipboard( result );
}

}
