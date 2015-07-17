//
//  MainWindowFilePanelState+OverlappedTerminalSupport.m
//  Files
//
//  Created by Michael G. Kazakov on 17/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#import "FilePanelOverlappedTerminal.h"

@implementation MainWindowFilePanelState (OverlappedTerminalSupport)

- (void) increaseBottomTerminalGap
{
    if( !m_OverlappedTerminal || self.isPanelsSplitViewHidden )
        return;
    m_OverlappedTerminalBottomGap++;
    m_OverlappedTerminalBottomGap = min(m_OverlappedTerminalBottomGap, m_OverlappedTerminal.totalScreenLines);
    [self frameDidChange];
}

- (void) decreaseBottomTerminalGap
{
    if( !m_OverlappedTerminal || self.isPanelsSplitViewHidden )
        return;
    if( m_OverlappedTerminalBottomGap == 0 )
        return;
    m_OverlappedTerminalBottomGap = min(m_OverlappedTerminalBottomGap, m_OverlappedTerminal.totalScreenLines);
    if( m_OverlappedTerminalBottomGap > 0 )
        m_OverlappedTerminalBottomGap--;
    [self frameDidChange];
}

@end
