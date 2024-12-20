// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CopyingTitleBuilder.h"
#include <Utility/PathManip.h>
#include <Utility/StringExtras.h>
#include "../Internal.h"

namespace nc::ops {

static NSString *ExtractCopyToName(std::string_view _s)
{
    using PM = utility::PathManip;
    if( PM::HasTrailingSlash(_s) ) {
        // "/hiss/meow/" -> "meow"
        return [NSString stringWithUTF8StdStringView:PM::Filename(_s)];
    }
    else {
        // "/hiss/meow.txt" -> "hiss"
        return [NSString stringWithUTF8StdStringView:PM::Filename(PM::Parent(_s))];
    }
}

static NSString *OpTitlePreffix(bool _copying)
{
    return _copying ? NSLocalizedString(@"Copying", "Prefix of a file operation")
                    : NSLocalizedString(@"Moving", "Prefix of a file operation");
}

static NSString *OpTitleForSingleItem(bool _copying, NSString *_item, NSString *_to)
{
    auto fmt = NSLocalizedString(@"%@ \u201c%@\u201d to \u201c%@\u201d", "");
    return [NSString stringWithFormat:fmt, OpTitlePreffix(_copying), _item, _to];
}

static NSString *OpTitleForMultipleItems(bool _copying, int _items, NSString *_to)
{
    auto fmt = NSLocalizedString(@"%@ %@ items to \u201c%@\u201d", "");
    return [NSString stringWithFormat:fmt, OpTitlePreffix(_copying), [NSNumber numberWithInt:_items], _to];
}

CopyingTitleBuilder::CopyingTitleBuilder(const std::vector<VFSListingItem> &_source_files,
                                         const std::string &_destination_path,
                                         const CopyingOptions &_options)
    : m_SourceFiles(_source_files), m_DestinationPath(_destination_path), m_Options(_options)
{
}

std::string CopyingTitleBuilder::TitleForPreparing() const
{
    if( m_SourceFiles.size() == 1 ) {
        auto name = m_SourceFiles.front().FilenameNS();
        auto fmt = m_Options.docopy ? NSLocalizedString(@"Preparing to copy \u201c%@\u201d", "")
                                    : NSLocalizedString(@"Preparing to move \u201c%@\u201d", "");
        return [NSString stringWithFormat:fmt, name].UTF8String;
    }
    else {
        auto amount = [NSNumber numberWithInt:static_cast<int>(m_SourceFiles.size())];
        auto fmt = m_Options.docopy ? NSLocalizedString(@"Preparing to copy %@ items", "")
                                    : NSLocalizedString(@"Preparing to move %@ items", "");
        return [NSString stringWithFormat:fmt, amount].UTF8String;
    }
}

std::string CopyingTitleBuilder::TitleForProcessing() const
{
    if( m_SourceFiles.size() == 1 )
        return OpTitleForSingleItem(
                   m_Options.docopy, m_SourceFiles.front().FilenameNS(), ExtractCopyToName(m_DestinationPath))
            .UTF8String;
    else
        return OpTitleForMultipleItems(
                   m_Options.docopy, static_cast<int>(m_SourceFiles.size()), ExtractCopyToName(m_DestinationPath))
            .UTF8String;
}

std::string CopyingTitleBuilder::TitleForVerifying()
{
    return NSLocalizedString(@"Verifying operation result..", "").UTF8String;
}

std::string CopyingTitleBuilder::TitleForCleanup()
{
    return NSLocalizedString(@"Cleaning up..", "").UTF8String;
}

} // namespace nc::ops
