//
//  JobView.m
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "JobView.h"
#include "JobData.h"
#include "FileOp.h"
#include "FileOpMassCopy.h"


@implementation JobView
{
//    NSTimer *m_UpdateTimer;
    JobData *m_Data;
    NSProgressIndicator *m_Progress;
    NSTextField         *m_Text;
    

    AbstractFileJob *m_LastJob;
    
    
    const FlexChainedStringsChunk::node *m_LastFileOpMassCopyItem;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.        
        NSRect progrect = NSMakeRect(5, 5, frame.size.width-10, 12);
        m_Progress = [[NSProgressIndicator alloc] initWithFrame:progrect];
        [m_Progress setStyle:NSProgressIndicatorBarStyle];
        [m_Progress setIndeterminate:false];
        [m_Progress setBezeled: true];
        [m_Progress setControlSize:NSMiniControlSize];
        [m_Progress setHidden:true];
        [self addSubview:m_Progress];
        
        NSRect textrect = NSMakeRect(5, 20, frame.size.width-10, 16);
        m_Text = [[NSTextField alloc] initWithFrame:textrect];
        [m_Text setEditable:false];
        [m_Text setBezeled:false];
        [m_Text setBordered:false];
        [m_Text setDrawsBackground:false];
        [m_Text setAlignment:NSCenterTextAlignment];
        [m_Text setHidden:true];
        [self addSubview:m_Text];
        
        m_LastJob = 0;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
        
        
    }

    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)frameDidChange
{
    NSRect fr = [self frame];

    [m_Progress setFrame:NSMakeRect(5, 5, fr.size.width-10, 12)];
    [m_Text setFrame:NSMakeRect(5, 20, fr.size.width-10, 16)];
}

- (void) SetJobData:(JobData*)_data
{
    m_Data = _data;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    
    // clear background
    CGContextSetRGBFillColor(context, 0.7,0.7,0.7,1);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

- (void)UpdateByTimer
{
    if(!m_Data)
        return;
    if( m_Data->NumberOfJobs() > 0 )
    {
        AbstractFileJob *topmost = m_Data->JobNo(0);
        if( m_LastJob != topmost )
        {
            // set controls regarding current job type
            if(FileCopy *fc = dynamic_cast<FileCopy*>(topmost))
                [self SetupForFileCopy:fc];
            else if(DirectoryCreate *dc = dynamic_cast<DirectoryCreate*>(topmost))
                [self SetupForDirectoryCreate:dc];
            else if(FileOpMassCopy *mc = dynamic_cast<FileOpMassCopy*>(topmost))
                [self SetupForMassCopy:mc];
            
            m_LastJob = topmost;
        }
        else   
        {
            // update current control set regarding current job state
            if(FileCopy *fc = dynamic_cast<FileCopy*>(m_LastJob))
                [self UpdateForFileCopy:fc];
            else if(DirectoryCreate *dc = dynamic_cast<DirectoryCreate*>(topmost))
                [self UpdateForDirectoryCreate:dc];
            else if(FileOpMassCopy *mc = dynamic_cast<FileOpMassCopy*>(topmost))
                [self UpdateForMassCopy:mc];
        }
    }
    else
    {
        if(m_LastJob != 0)
        {
            // some cleanup code here
            [self Cleanup];
            
            m_LastJob = 0;
        }
    }
}

- (void) Cleanup
{
    [m_Progress setHidden:true];
    [m_Text setHidden:true];
}

- (void) SetupForFileCopy: (FileCopy*) _fc
{    
    [m_Progress setMinValue:0.];
    [m_Progress setMaxValue:1.];
    [m_Progress setDoubleValue:_fc->Done()];
    [m_Progress setHidden:false];
    
    [m_Text setHidden:false];
}

- (void) UpdateForFileCopy: (FileCopy*) _fc
{
    [m_Progress setDoubleValue:_fc->Done()];
    [m_Text setDoubleValue:_fc->BytesPerSecond()];    
}

- (void) SetupForDirectoryCreate: (DirectoryCreate*) _dc
{
    [m_Progress setMinValue:0.];
    [m_Progress setMaxValue:1.];
    [m_Progress setDoubleValue:_dc->Done()];
    [m_Progress setHidden:false];
    [m_Text setHidden:true];
}

- (void) UpdateForDirectoryCreate: (DirectoryCreate*) _dc
{
    [m_Progress setDoubleValue:_dc->Done()];
}

- (void) SetupForMassCopy: (FileOpMassCopy*) _mc
{
    [m_Progress setMinValue:0.];
    [m_Progress setMaxValue:1.];
    [m_Progress setDoubleValue:_mc->Done()];
    [m_Progress setHidden:false];
    [m_Progress setIndeterminate:true];
    [m_Progress startAnimation:self];
    [m_Text setHidden:false];
//    [m_Text setAlignment:NSRightTextAlignment];
    m_LastFileOpMassCopyItem = 0;
}

- (void) UpdateForMassCopy: (FileOpMassCopy*) _mc
{
    if(_mc->State() == FileOpMassCopy::StateCopying)
    {
        if([m_Progress isIndeterminate])
        {
            [m_Progress stopAnimation:self];
            [m_Progress setIndeterminate:false];
        }
        
        [m_Progress setDoubleValue:_mc->Done()];
        
        if(m_LastFileOpMassCopyItem != _mc->CurrentlyProcessingItem())
        {
            m_LastFileOpMassCopyItem = _mc->CurrentlyProcessingItem();
            if(m_LastFileOpMassCopyItem != 0)
            {
//                char itemname[__DARWIN_MAXPATHLEN];
//                m_LastFileOpMassCopyItem->str_with_pref(itemname);
                [m_Text setStringValue:[NSString
                                        stringWithUTF8String:m_LastFileOpMassCopyItem->str()
                                        ]
                    ];
            }
        }
    }
}


@end
