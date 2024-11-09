// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowPanelsTabOperationsConcurrencySheet.h"
#include <Base/algo.h>
#include <ankerl/unordered_dense.h>
#include <vector>
#include <ranges>
#include <fmt/core.h>
#include <fmt/ranges.h>

@interface PreferencesWindowPanelsTabOperationsConcurrencySheet ()
@property(strong, nonatomic) IBOutlet NSButton *opCopy;
@property(strong, nonatomic) IBOutlet NSButton *opDelete;
@property(strong, nonatomic) IBOutlet NSButton *opMkdir;
@property(strong, nonatomic) IBOutlet NSButton *opLink;
@property(strong, nonatomic) IBOutlet NSButton *opCompress;
@property(strong, nonatomic) IBOutlet NSButton *opBatchRename;
@property(strong, nonatomic) IBOutlet NSButton *opChAttrs;
@end

@implementation PreferencesWindowPanelsTabOperationsConcurrencySheet {
    std::string m_OriginalExclusionList;
    std::string m_FinalExclusionList;
    ankerl::unordered_dense::map<std::string, NSButton *> m_Tags;
}

@synthesize exclusionList = m_FinalExclusionList;
@synthesize opCopy;
@synthesize opDelete;
@synthesize opMkdir;
@synthesize opLink;
@synthesize opCompress;
@synthesize opBatchRename;
@synthesize opChAttrs;

- (instancetype)initWithConcurrencyExclusionList:(const std::string &)_list
{
    self = [super init];
    if( self ) {
        m_OriginalExclusionList = _list;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    m_Tags.emplace("copy", self.opCopy);
    m_Tags.emplace("attrs_change", self.opChAttrs);
    m_Tags.emplace("batch_rename", self.opBatchRename);
    m_Tags.emplace("compress", self.opCompress);
    m_Tags.emplace("delete", self.opDelete);
    m_Tags.emplace("mkdir", self.opMkdir);
    m_Tags.emplace("link", self.opLink);

    // by default all are on
    for( auto &p : m_Tags )
        [p.second setState:NSControlStateValueOn];

    // now turn off everything which is excluded from queueing
    std::vector<std::string> excluded;
    for( const auto str : std::views::split(std::string_view{m_OriginalExclusionList}, ',') )
        if( auto trimmed = nc::base::Trim(std::string_view{str}); !trimmed.empty() )
            excluded.emplace_back(trimmed);

    for( auto &operation : excluded )
        if( m_Tags.contains(operation) )
            [m_Tags[operation] setState:NSControlStateValueOff];
}

- (IBAction)onOK:(id)sender
{
    // gather all operations that don't have check ticks
    std::vector<std::string> excluded;
    for( auto &p : m_Tags )
        if( p.second.state == NSControlStateValueOff )
            excluded.push_back(p.first);
    m_FinalExclusionList = fmt::format("{}", fmt::join(excluded, ", "));

    // report that we're done
    [self endSheet:NSModalResponseOK];
}

@end
