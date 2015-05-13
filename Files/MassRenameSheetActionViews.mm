//
//  MassRenameSheetActionViews.m
//  Files
//
//  Created by Michael G. Kazakov on 13/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "MassRenameSheetController.h"
#import "Common.h"

static NSView *FindViewWithIdentifier(NSView *v, NSString *identifier)
{
    for (NSView *view in v.subviews)
        if ([view.identifier isEqualToString:identifier])
            return view;
    return nil;
}

@interface NSControl(fire)
- (void) fireAction;
@end
@implementation NSControl(fire)
- (void) fireAction
{
    [self sendAction:self.action to:self.target];
}
@end


//////////////////////////////////////////////////////////////////////////////// MassRenameSheetAddText

@implementation MassRenameSheetAddText
{
    NSPopUpButton          *m_AddIn;
    NSPopUpButton          *m_AddWhere;
    NSTextField            *m_TextToAdd;
    string                  m_ValTextToAdd;
    MassRename::ApplyTo     m_ValAddIn;
    MassRename::Position    m_ValAddWhere;
}

@synthesize text = m_ValTextToAdd;
@synthesize addIn = m_ValAddIn;
@synthesize addWhere = m_ValAddWhere;

- (void)viewWillMoveToSuperview:(NSView *)_view
{
    [super viewWillMoveToSuperview:_view];
    if( !m_TextToAdd ) {
        m_TextToAdd = (NSTextField*)FindViewWithIdentifier(self, @"add_text");
        m_TextToAdd.action = @selector(OnTextChanged:);
        m_TextToAdd.target = self;
        m_TextToAdd.delegate = self;
    }
    if( !m_AddIn ) {
        m_AddIn = (NSPopUpButton*)FindViewWithIdentifier(self, @"add_in");
        m_AddIn.action = @selector(OnInChanged:);
        m_AddIn.target = self;
    }
    if( !m_AddWhere ) {
        m_AddWhere = (NSPopUpButton*)FindViewWithIdentifier(self, @"add_where");
        m_AddWhere.action = @selector(OnWhereChanged:);
        m_AddWhere.target = self;
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( auto tf = objc_cast<NSTextField>(notification.object) )
        [self OnTextChanged:tf];
}

- (IBAction)OnTextChanged:(id)sender
{
    const char *new_text = m_TextToAdd.stringValue ? m_TextToAdd.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValTextToAdd == new_text )
        return;
    m_ValTextToAdd = new_text;
    [self fireAction];
}

- (IBAction)OnInChanged:(id)sender
{
    auto new_v = MassRename::ApplyTo(m_AddIn.selectedTag);
    if(new_v == m_ValAddIn)
        return;
    m_ValAddIn = new_v;
    [self fireAction];
}

- (IBAction)OnWhereChanged:(id)sender
{
    auto new_v = MassRename::Position(m_AddWhere.selectedTag);
    if(new_v == m_ValAddWhere)
        return;
    m_ValAddWhere = new_v;
    [self fireAction];
}

@end

//////////////////////////////////////////////////////////////////////////////// MassRenameSheetReplaceText

@implementation MassRenameSheetReplaceText
{
    NSPopUpButton                          *m_ReplaceIn;
    NSPopUpButton                          *m_Mode;
    NSButton                               *m_Senstive;
    NSTextField                            *m_What;
    NSTextField                            *m_With;
    
    string                                  m_ValWhat;
    string                                  m_ValWith;
    bool                                    m_ValSensitive;
    MassRename::ApplyTo                     m_ValIn;
    MassRename::ReplaceText::ReplaceMode    m_ValMode;
}

@synthesize what = m_ValWhat;
@synthesize with = m_ValWith;
@synthesize caseSensitive = m_ValSensitive;
@synthesize replaceIn = m_ValIn;
@synthesize mode = m_ValMode;

- (void)viewWillMoveToSuperview:(NSView *)_view
{
    [super viewWillMoveToSuperview:_view];
    if( !m_What ) {
        m_What = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"replace_what"));
        m_What.action = @selector(OnWhatChanged:);
        m_What.target = self;
        m_What.delegate = self;
    }
    if( !m_With ) {
        m_With = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"replace_with"));
        m_With.action = @selector(OnWithChanged:);
        m_With.target = self;
        m_With.delegate = self;
    }
    if( !m_ReplaceIn ) {
        m_ReplaceIn = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"replace_in"));
        m_ReplaceIn.action = @selector(OnInChanged:);
        m_ReplaceIn.target = self;
    }
    if( !m_Mode ) {
        m_Mode = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"replace_mode"));
        m_Mode.action = @selector(OnModeChanged:);
        m_Mode.target = self;
    }
    if( !m_Senstive ) {
        m_Senstive = objc_cast<NSButton>( FindViewWithIdentifier(self, @"replace_casesens"));
        m_Senstive.action = @selector(OnSensChanged:);
        m_Senstive.target = self;
    }
}

- (IBAction)OnInChanged:(id)sender
{
    auto new_v = MassRename::ApplyTo(m_ReplaceIn.selectedTag);
    if(new_v == m_ValIn)
        return;
    m_ValIn = new_v;
    [self fireAction];
}

- (IBAction)OnModeChanged:(id)sender
{
    auto new_v = MassRename::ReplaceText::ReplaceMode(m_Mode.selectedTag);
    if(new_v == m_ValMode)
        return;
    m_ValMode = new_v;
    [self fireAction];

    auto is_whole = m_ValMode == MassRename::ReplaceText::ReplaceMode::WholeText;
    m_Senstive.enabled = !is_whole;
    m_What.enabled = !is_whole;
}

- (IBAction)OnSensChanged:(id)sender
{
    bool checked = m_Senstive.state == NSOnState;
    if( checked == m_ValSensitive )
        return;
    m_ValSensitive = checked;
    [self fireAction];
}

- (IBAction)OnWhatChanged:(id)sender
{
    const char *new_text = m_What.stringValue ? m_What.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValWhat == new_text )
        return;
    m_ValWhat = new_text;
    [self fireAction];
}

- (IBAction)OnWithChanged:(id)sender
{
    const char *new_text = m_With.stringValue ? m_With.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValWith == new_text )
        return;
    m_ValWith = new_text;
    [self fireAction];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == m_With )
        [self OnWithChanged:m_With];
    else if( objc_cast<NSTextField>(notification.object) == m_What )
        [self OnWhatChanged:m_What];
}

@end

//////////////////////////////////////////////////////////////////////////////// MassRenameSheetInsertSequence

@implementation MassRenameSheetInsertSequence
{
    NSTextField            *m_Start;
    NSStepper              *m_StartSt;
    NSTextField            *m_Step;
    NSStepper              *m_StepSt;
    NSTextField            *m_Prefix;
    NSTextField            *m_Suffix;
    NSPopUpButton          *m_Width;
    NSPopUpButton          *m_In;
    NSPopUpButton          *m_Where;
    
    string                  m_ValPrefix;
    string                  m_ValSuffix;
    MassRename::ApplyTo     m_ValIn;
    MassRename::Position    m_ValWhere;
    long                    m_ValStart;
    long                    m_ValStep;
    int                     m_ValWidth;
}
@synthesize prefix = m_ValPrefix;
@synthesize suffix = m_ValSuffix;
@synthesize insertIn = m_ValIn;
@synthesize insertWhere = m_ValWhere;
@synthesize start = m_ValStart;
@synthesize step = m_ValStep;
@synthesize width = m_ValWidth;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self) {
        m_ValStart = 1;
        m_ValStep = 1;
        m_ValWidth = 1;
        m_ValIn = MassRename::ApplyTo::FullName;
        m_ValWhere = MassRename::Position::Beginning;
    }
    return self;
}

- (NSNumberFormatter*)formatter
{
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.usesGroupingSeparator = false;
    return fmt;
}

- (void)viewWillMoveToSuperview:(NSView *)_view
{
    [super viewWillMoveToSuperview:_view];
    if( !m_Start ) {
        m_Start = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"seq_init"));
        m_Start.integerValue = m_ValStart;
        m_Start.action = @selector(OnStartChanged:);
        m_Start.target = self;
        m_Start.delegate = self;
        m_Start.formatter = self.formatter;
    }
    if( !m_StartSt ) {
        m_StartSt = objc_cast<NSStepper>(FindViewWithIdentifier(self, @"seq_init_st"));
        m_StartSt.minValue = -1000000000.;
        m_StartSt.maxValue =  1000000000.;
        m_StartSt.increment = 1.;
        m_StartSt.integerValue = m_ValStart;
        m_StartSt.action = @selector(OnStartChanged:);
        m_StartSt.target = self;
    }
    if( !m_Step ) {
        m_Step = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"seq_step"));
        m_Step.integerValue = m_ValStep;
        m_Step.action = @selector(OnStepChanged:);
        m_Step.target = self;
        m_Step.delegate = self;
        m_Step.formatter = self.formatter;
    }
    if( !m_StepSt ) {
        m_StepSt = objc_cast<NSStepper>(FindViewWithIdentifier(self, @"seq_step_st"));
        m_StepSt.minValue = -1000.;
        m_StepSt.maxValue =  1000;
        m_StepSt.increment = 1.;
        m_StepSt.integerValue = m_ValStep;
        m_StepSt.action = @selector(OnStepChanged:);
        m_StepSt.target = self;
    }
    if( !m_Prefix ) {
        m_Prefix = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"seq_prefix"));
        m_Prefix.stringValue =  [NSString stringWithUTF8StdString:m_ValPrefix];
        m_Prefix.action = @selector(OnPrefixChanged:);
        m_Prefix.target = self;
        m_Prefix.delegate = self;
    }
    if( !m_Suffix ) {
        m_Suffix = objc_cast<NSTextField>(FindViewWithIdentifier(self, @"seq_suffix"));
        m_Suffix.stringValue = [NSString stringWithUTF8StdString:m_ValSuffix];
        m_Suffix.action = @selector(OnSuffixChanged:);
        m_Suffix.target = self;
        m_Suffix.delegate = self;
    }
    if( !m_Width ) {
        m_Width = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"seq_width"));
        [m_Width selectItemWithTag:m_ValWidth];
        m_Width.action = @selector(OnWidthChanged:);
        m_Width.target = self;
    }
    if( !m_In ) {
        m_In = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"seq_in"));
        [m_In selectItemWithTag:(int)m_ValIn];
        m_In.action = @selector(OnInChanged:);
        m_In.target = self;
    }
    if( !m_Where ) {
        m_Where = objc_cast<NSPopUpButton>(FindViewWithIdentifier(self, @"seq_where"));
        [m_Where selectItemWithTag:(int)m_ValWhere];
        m_Where.action = @selector(OnWhereChanged:);
        m_Where.target = self;
    }
    
}

- (IBAction)OnWhereChanged:(id)sender
{
    auto new_v = MassRename::Position(m_Where.selectedTag);
    if(new_v == m_ValWhere)
        return;
    m_ValWhere = new_v;
    [self fireAction];
}

- (IBAction)OnInChanged:(id)sender
{
    auto new_v = MassRename::ApplyTo(m_In.selectedTag);
    if(new_v == m_ValIn)
        return;
    m_ValIn = new_v;
    [self fireAction];
}

- (IBAction)OnWidthChanged:(id)sender
{
    int width = (int)m_Width.selectedTag;
    if(m_ValWidth == width)
        return;
    m_ValWidth = width;
    [self fireAction];
}

- (IBAction)OnStartChanged:(id)sender
{
    long start = [sender integerValue];
    if( m_ValStart == start )
        return;
    m_ValStart = start;
    [self fireAction];
    m_Start.integerValue = m_ValStart;
    m_StartSt.integerValue = m_ValStart;
}

- (IBAction)OnStepChanged:(id)sender
{
    long step = [sender integerValue];
    if( m_ValStep == step )
        return;
    m_ValStep = step;
    [self fireAction];
    m_Step.integerValue = m_ValStep;
    m_StepSt.integerValue = m_ValStep;
}

- (IBAction)OnPrefixChanged:(id)sender
{
    const char *new_text = m_Prefix.stringValue ? m_Prefix.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValPrefix == new_text )
        return;
    m_ValPrefix = new_text;
    [self fireAction];
}

- (IBAction)OnSuffixChanged:(id)sender
{
    const char *new_text = m_Suffix.stringValue ? m_Suffix.stringValue.fileSystemRepresentationSafe : "";
    if( m_ValSuffix  == new_text )
        return;
    m_ValSuffix = new_text;
    [self fireAction];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == m_Start )
        [self OnStartChanged:m_Start];
    else if( objc_cast<NSTextField>(notification.object) == m_Step )
        [self OnStepChanged:m_Step];
    else if( objc_cast<NSTextField>(notification.object) == m_Prefix )
        [self OnPrefixChanged:m_Prefix];
    else if( objc_cast<NSTextField>(notification.object) == m_Suffix )
        [self OnSuffixChanged:m_Suffix];
}

@end