// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Quartz/Quartz.h>
#include "BigFileViewProtocol.h"

class InternalViewerViewPreviewMode : public BigFileViewImpl
{
public:
    InternalViewerViewPreviewMode(const string &_native_path, BigFileView* _view);
    ~InternalViewerViewPreviewMode();
    
    bool NeedsVerticalScroller() override;
    void DoDraw(CGContextRef _context, NSRect _dirty_rect) override;
    
private:
    const string m_NativePath;
    QLPreviewView * const m_Preview;
    __weak BigFileView * const m_View;
};
