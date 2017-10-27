// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BigFileView.h"
#include "InternalViewerViewPreviewMode.h"

InternalViewerViewPreviewMode::InternalViewerViewPreviewMode(const string &_native_path, BigFileView* _view):
    m_NativePath(_native_path),
    m_View(_view),
    m_Preview([[QLPreviewView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)])
{
    m_Preview.translatesAutoresizingMaskIntoConstraints = false;
    if( NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:_native_path]] )
        m_Preview.previewItem = url;
    [_view addSubview:m_Preview];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_Preview);
    [_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_Preview]-(==0)-|" options:0 metrics:nil views:views]];
    [_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_Preview]-(==0)-|" options:0 metrics:nil views:views]];
}


InternalViewerViewPreviewMode::~InternalViewerViewPreviewMode()
{
    [m_Preview removeFromSuperview];
}

void InternalViewerViewPreviewMode::DoDraw(CGContextRef _context, NSRect _dirty_rect)
{
//    [m_View BackgroundFillColor].Set(_context);
    CGContextSetFillColorWithColor(_context, m_View.BackgroundFillColor);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
}

bool InternalViewerViewPreviewMode::NeedsVerticalScroller()
{
    return false;
}
