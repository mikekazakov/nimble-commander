// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import "PreferencesWindowPanelsTabColoringFilterSheet.h"

static NSCellStateValue tribool_to_state(tribool _val)
{
    if(_val == false)
        return NSOffState;
    else if(_val == true)
        return NSOnState;
    else
        return NSMixedState;
}

static tribool state_to_tribool(NSCellStateValue _val)
{
    if(_val == NSOnState)
        return true;
    else if(_val == NSOffState)
        return false;
    else
        return indeterminate;
}

@implementation PreferencesWindowPanelsTabColoringFilterSheet
{
    PanelViewPresentationItemsColoringFilter m_Filter;
    
}

- (id) initWithFilter:(PanelViewPresentationItemsColoringFilter)_filter
{
    self = [super init];
    if(self) {
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

- (void)cancelOperation:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnOK:(id)sender
{
    m_Filter.executable = state_to_tribool(self.executable.state);
    m_Filter.hidden = state_to_tribool(self.hidden.state);
    m_Filter.directory = state_to_tribool(self.directory.state);
    m_Filter.symlink = state_to_tribool(self.symlink.state);
    m_Filter.reg = state_to_tribool(self.regular.state);
    m_Filter.selected = state_to_tribool(self.selected.state);
    NSString *mask = self.mask.stringValue;
    if(mask == nil)
        mask = @"";
    else if( !FileMask::IsWildCard(mask.UTF8String) )
        if(NSString *replace = [NSString stringWithUTF8StdString:FileMask::ToExtensionWildCard(mask.UTF8String)])
            mask = replace;
    m_Filter.mask = mask.UTF8String;
    [self endSheet:NSModalResponseOK];
}

- (PanelViewPresentationItemsColoringFilter) filter
{
    return m_Filter;
}

@end
