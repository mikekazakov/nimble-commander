//
//  MainWindowBigFileViewState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowBigFileViewState.h"
#import "BigFileView.h"
#import "FileWindow.h"
#import "MainWindowController.h"
#import "Common.h"

static NSMutableDictionary *EncodingToDict(int _encoding, NSString *_name)
{
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            _name, @"name",
            [NSNumber numberWithInt:_encoding], @"code",
            nil
            ];
}

@implementation MainWindowBigFileViewState
{
    FileWindow  *m_FileWindow;
    BigFileView *m_View;
    NSPopUpButton *m_EncodingSelect;
    NSMutableArray *m_Encodings;
    NSButton    *m_WordWrap;
    
    char        m_FilePath[MAXPATHLEN];
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        m_Encodings = [NSMutableArray new];
        [self CreateControls];
    }
    return self;
}

- (void) dealloc
{
    if(m_FileWindow != 0)
    {
        if(m_FileWindow->FileOpened())
            m_FileWindow->CloseFile();
        delete m_FileWindow;
        m_FileWindow = 0;
    }
}

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
    [self.window makeFirstResponder:m_View];
    [self UpdateTitle];    
}

- (void) Resigned
{
    
    
}

- (void) UpdateTitle
{
    NSString *path = [NSString stringWithUTF8String:m_FilePath];
    
    // find window geometry
    NSWindow* window = [self window];
    float leftEdge = NSMaxX([[window standardWindowButton:NSWindowZoomButton] frame]);
    NSButton* fsbutton = [window standardWindowButton:NSWindowFullScreenButton];
    float rightEdge = fsbutton ? [fsbutton frame].origin.x : NSMaxX([window frame]);
    
    // Leave 8 pixels of padding around the title.
    const int kTitlePadding = 8;
    float titleWidth = rightEdge - leftEdge - 2 * kTitlePadding;
    
    // Sending |titleBarFontOfSize| 0 returns default size
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont titleBarFontOfSize:0] forKey:NSFontAttributeName];
    window.title = StringByTruncatingToWidth(path, titleWidth, kTruncateAtStart, attributes);
    
}

- (void)cancelOperation:(id)sender
{
    [m_View DoClose];
    [(MainWindowController*)[[self window] delegate] ResignAsWindowState:self];
}

- (bool) OpenFile: (const char*) _fn
{    
    FileWindow *fw = new FileWindow;
    if(fw->OpenFile(_fn) == 0)
    {
        if(m_FileWindow != 0)
        {
            if(m_FileWindow->FileOpened())
                m_FileWindow->CloseFile();
            delete m_FileWindow;
            m_FileWindow = 0;
        }
        
        m_FileWindow = fw;
        strcpy(m_FilePath, _fn);
        [m_View SetFile:m_FileWindow];
        
        // update UI
        [self SelectEncodingFromView];
        [m_WordWrap setState:[m_View WordWrap] ? NSOnState : NSOffState];
        
        return true;
    }
    else
    {
        delete fw;
        return false;
    }
}

- (void) CreateControls
{
    m_View = [[BigFileView alloc] initWithFrame:self.frame];
    [m_View setTranslatesAutoresizingMaskIntoConstraints:NO];    
    [self addSubview:m_View];
    
    m_EncodingSelect = [[NSPopUpButton alloc] initWithFrame:NSRect()];
    [m_EncodingSelect setTranslatesAutoresizingMaskIntoConstraints:NO];
    [(NSPopUpButtonCell*)[m_EncodingSelect cell] setControlSize:NSSmallControlSize];
    [m_EncodingSelect setTarget:self];
    [m_EncodingSelect setAction:@selector(SelectedEncoding:)];
    [self addSubview:m_EncodingSelect];

    m_WordWrap = [[NSButton alloc] initWithFrame:NSRect()];
    [m_WordWrap setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_WordWrap setButtonType:NSSwitchButton];
    [m_WordWrap setTitle:@"Word wrap"];
    [m_WordWrap setTarget:self];
    [m_WordWrap setAction:@selector(WordWrapChanged:)];
    [self addSubview:m_WordWrap];
    
    NSBox *line = [[NSBox alloc] initWithFrame:NSRect()];
    [line setTranslatesAutoresizingMaskIntoConstraints:NO];
    [line setBoxType:NSBoxSeparator];
    [self addSubview:line];

    NSDictionary *views = NSDictionaryOfVariableBindings(m_View, m_EncodingSelect, m_WordWrap, line);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(<=1)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[line]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[m_EncodingSelect]-[m_WordWrap]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[m_EncodingSelect(18)]-[line(<=1)]-(==0)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    
    [self FillEncodingSelection];
}

- (void) FillEncodingSelection
{
    [m_Encodings addObject:EncodingToDict(ENCODING_MACOS_ROMAN_WESTERN, @"Western (Mac OS Roman)")];
    [m_Encodings addObject:EncodingToDict(ENCODING_OEM866, @"OEM 866 (DOS)")];
    [m_Encodings addObject:EncodingToDict(ENCODING_WIN1251, @"Windows 1251")];
    [m_Encodings addObject:EncodingToDict(ENCODING_UTF8, @"UTF-8")];
    
    for(NSMutableDictionary *d in m_Encodings)
        [m_EncodingSelect addItemWithTitle:[d objectForKey:@"name"]];
}

- (void) SelectEncodingFromView
{
    int current_encoding = [m_View Enconding];
    for(NSMutableDictionary *d in m_Encodings)
        if([(NSNumber*)[d objectForKey:@"code"] intValue] == current_encoding)
        {
            [m_EncodingSelect selectItemWithTitle:[d objectForKey:@"name"]];
            break;
        }
}

- (void) SelectedEncoding:(id)sender
{
    for(NSMutableDictionary *d in m_Encodings)
        if([[d objectForKey:@"name"] isEqualToString:[[m_EncodingSelect selectedItem] title]])
        {
            [m_View SetEncoding:[(NSNumber*)[d objectForKey:@"code"] intValue]];
            break;
        }
}

- (void) WordWrapChanged:(id)sender
{
    [m_View SetWordWrap: [m_WordWrap state]==NSOnState];
}

@end
