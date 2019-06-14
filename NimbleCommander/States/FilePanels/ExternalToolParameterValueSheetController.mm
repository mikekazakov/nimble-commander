// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalToolParameterValueSheetController.h"
#include <Utility/CocoaAppearanceManager.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

@interface ExternalToolParameterValueSheetController ()

@property (nonatomic) IBOutlet NSLayoutConstraint *buttonConstraint;
@property (nonatomic) IBOutlet NSView *valueBlockView;
@property (nonatomic) IBOutlet NSButton *okButton;

@end

@implementation ExternalToolParameterValueSheetController
{
    std::vector<std::string> m_ValueNames;
    std::vector<std::string> m_Values;
}

@synthesize values = m_Values;

- (id) initWithValueNames:(std::vector<std::string>)_names
{
    self = [super init];
    if( self ) {
        assert(!_names.empty());
        m_ValueNames = move(_names);
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);    
    
    m_Values.resize( m_ValueNames.size() );
    
    
    NSView *prev_block = nil;
    int number = 0;
    for( auto &s: m_ValueNames ) {
    
        NSView *v = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self.valueBlockView]];
        
        NSTextField *tf1 = [v viewWithTag:1];
        if( !s.empty()  )
            tf1.stringValue = [NSString stringWithUTF8StdString:s + ":"];
        else
            tf1.stringValue = [NSString stringWithFormat:@"Parameter #%d:", number];
        
        NSTextField *tf2 = [v viewWithTag:2];
        tf2.target = self;
        tf2.tag = number;

        
        auto views = NSDictionaryOfVariableBindings(v);
        [self.window.contentView addSubview:v];
        [self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[v]-|" options:0 metrics:nil views:views]];
        if( !prev_block )
            [self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[v]" options:0 metrics:nil views:views]];
        else {
            views = NSDictionaryOfVariableBindings(v, prev_block);
            [self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[prev_block]-[v]" options:0 metrics:nil views:views]];
        }
        
        prev_block = v;
        number++;
    }
    
    auto button = self.okButton;
    auto views = NSDictionaryOfVariableBindings(prev_block, button);
    [self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[prev_block]-[button]" options:0 metrics:nil views:views]];
    [self.window.contentView layoutSubtreeIfNeeded];
}

- (IBAction)onOK:(id)[[maybe_unused]]_sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id)[[maybe_unused]]_sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)onValueChanged:(id)sender
{
    if( auto tf = objc_cast<NSTextField>(sender) ) {
        assert( tf.tag < (int)m_Values.size() );
        m_Values[tf.tag] = tf.stringValue.UTF8String;
    }
}

@end
