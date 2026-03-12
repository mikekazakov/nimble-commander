// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/Config.h>
#include "../PanelController.h"
#include "../PanelView.h"
#include "CopyFilePaths.h"
#include <VFS/VFS.h>
#include <functional>
#include <Utility/StringExtras.h>
#include <numeric>

namespace nc::panel::actions {

static const char *Separator()
{
    static const auto config_path = "filePanel.general.separatorForCopyingMultipleFilenames";
    [[clang::no_destroy]] static const auto s = GlobalConfig().GetString(config_path);
    return s.c_str();
}

static void WriteSingleStringToClipboard(const std::string &_s)
{
    NSPasteboard *const pb = NSPasteboard.generalPasteboard;
    [pb declareTypes:@[NSPasteboardTypeString] owner:nil];
    [pb setString:[NSString stringWithUTF8StdString:_s] forType:NSPasteboardTypeString];
}

static std::string JoinItemStrings(const std::vector<VFSListingItem> &_entries,
                                   const std::function<std::string(const VFSListingItem &)> &_projection)
{
    return std::accumulate(std::begin(_entries), std::end(_entries), std::string{}, [&](const auto &a, const auto &b) {
        return a + (a.empty() ? "" : Separator()) + _projection(b);
    });
}

bool CopyFileName::Predicate(PanelController *_source) const
{
    return _source.view.item;
}

bool CopyFilePath::Predicate(PanelController *_source) const
{
    return _source.view.item;
}

bool CopyFileDirectory::Predicate(PanelController *_source) const
{
    return _source.view.item;
}

void CopyFileName::Perform(PanelController *_source, id /*_sender*/) const
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    WriteSingleStringToClipboard(JoinItemStrings(entries, [](const auto &item) { return item.Filename(); }));
}

void CopyFilePath::Perform(PanelController *_source, id /*_sender*/) const
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    WriteSingleStringToClipboard(JoinItemStrings(entries, [](const auto &item) { return item.Path(); }));
}

void CopyFileDirectory::Perform(PanelController *_source, id /*_sender*/) const
{
    const auto entries = _source.selectedEntriesOrFocusedEntry;
    WriteSingleStringToClipboard(JoinItemStrings(entries, [](const auto &item) { return item.Directory(); }));
}

context::CopyPathname::CopyPathname(const std::vector<VFSListingItem> &_items) : m_Items(_items)
{
    if( _items.empty() )
        throw std::invalid_argument("CopyPathname was made with empty items set");
}

bool context::CopyPathname::Predicate([[maybe_unused]] PanelController *_source) const
{
    return !m_Items.empty();
}

bool context::CopyPathname::ValidateMenuItem([[maybe_unused]] PanelController *_source, NSMenuItem *_item) const
{
    if( m_Items.size() > 1 ) {
        _item.title =
            [NSString stringWithFormat:NSLocalizedStringFromTable(@"Copy %lu Items as Pathnames",
                                                                  @"FilePanelsContextMenu",
                                                                  "Copy many items as plain-text pathnames"),
                                     m_Items.size()];
    }
    else {
        _item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(
                                                     @"Copy “%@” as Pathname",
                                                     @"FilePanelsContextMenu",
                                                     "Copy one item as a plain-text pathname"),
                                                 m_Items.front().DisplayNameNS()];
    }
    return Predicate(_source);
}

void context::CopyPathname::Perform([[maybe_unused]] PanelController *_source, id /*_sender*/) const
{
    WriteSingleStringToClipboard(JoinItemStrings(m_Items, [](const auto &item) { return item.Path(); }));
}

} // namespace nc::panel::actions
