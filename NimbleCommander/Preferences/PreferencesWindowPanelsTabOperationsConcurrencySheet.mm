// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowPanelsTabOperationsConcurrencySheet.h"
#include <boost/algorithm/string.hpp>
#include <robin_hood.h>
#include <vector>

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
    robin_hood::unordered_map<std::string, NSButton *> m_Tags;
}

@synthesize exclusionList = m_FinalExclusionList;

- (instancetype)initWithConcurrencyExclusionList:(const std::string &)_list
{
    if( self = [super init] ) {
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
    boost::split(
        excluded,
        m_OriginalExclusionList,
        [](char _c) { return _c == ','; },
        boost::token_compress_on);
    for( auto &entry : excluded )
        boost::trim(entry);
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
    m_FinalExclusionList = boost::algorithm::join(excluded, ", ");

    // report that we're done
    [self endSheet:NSModalResponseOK];
}

@end
