// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowPanelsTabColoringFilterSheet.h"
#include <Utility/StringExtras.h>

using nc::base::indeterminate;
using nc::base::tribool;

static NSControlStateValue tribool_to_state(tribool _val)
{
    if( _val == false )
        return NSControlStateValueOff;
    else if( _val == true )
        return NSControlStateValueOn;
    else
        return NSControlStateValueMixed;
}

static tribool state_to_tribool(NSControlStateValue _val)
{
    if( _val == NSControlStateValueOn )
        return true;
    else if( _val == NSControlStateValueOff )
        return false;
    else
        return indeterminate;
}

@implementation PreferencesWindowPanelsTabColoringFilterSheet {
    nc::panel::PresentationItemsColoringFilter m_Filter;
}
@synthesize executable;
@synthesize hidden;
@synthesize directory;
@synthesize symlink;
@synthesize regular;
@synthesize selected;
@synthesize mask;

- (id)initWithFilter:(nc::panel::PresentationItemsColoringFilter)_filter
{
    self = [super init];
    if( self ) {
        m_Filter = _filter;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.executable.state = tribool_to_state(m_Filter.executable);
    self.hidden.state = tribool_to_state(m_Filter.hidden);
    self.directory.state = tribool_to_state(m_Filter.directory);
    self.symlink.state = tribool_to_state(m_Filter.symlink);
    self.regular.state = tribool_to_state(m_Filter.reg);
    self.selected.state = tribool_to_state(m_Filter.selected);
    self.mask.stringValue = [NSString stringWithUTF8StdString:m_Filter.mask.Mask()];
}

- (void)cancelOperation:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnOK:(id) [[maybe_unused]] _sender
{
    m_Filter.executable = state_to_tribool(self.executable.state);
    m_Filter.hidden = state_to_tribool(self.hidden.state);
    m_Filter.directory = state_to_tribool(self.directory.state);
    m_Filter.symlink = state_to_tribool(self.symlink.state);
    m_Filter.reg = state_to_tribool(self.regular.state);
    m_Filter.selected = state_to_tribool(self.selected.state);
    NSString *mask_str = self.mask.stringValue;
    if( mask_str == nil ) {
        mask_str = @"";
    }
    else if( !nc::utility::FileMask::IsWildCard(mask_str.UTF8String) ) {
        auto wc = nc::utility::FileMask::ToExtensionWildCard(mask_str.UTF8String);
        if( auto replace = [NSString stringWithUTF8StdString:wc] )
            mask_str = replace;
    }
    m_Filter.mask = nc::utility::FileMask(mask_str.UTF8String);
    [self endSheet:NSModalResponseOK];
}

- (nc::panel::PresentationItemsColoringFilter)filter
{
    return m_Filter;
}

@end
