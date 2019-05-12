// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

//#include "BigFileViewDataBackend.h"

#include <Cocoa/Cocoa.h>

#if 0

@class BigFileView;

class BigFileViewImpl
{
public:
    
    virtual ~BigFileViewImpl(){};
    
    // information
    virtual uint32_t GetOffsetWithinWindow(){return 0;}; // offset of a first visible symbol (+/-)
    
    virtual void CalculateScrollPosition( double &_position, double &_knob_proportion ){_position = 0; _knob_proportion = 1;};
    // event handling
    virtual void OnScrollWheel(NSEvent *theEvent){}
    virtual void OnBufferDecoded() {}
    virtual void OnFrameChanged() {}
    virtual void OnFontSettingsChanged(){} // may need to rebuild layout here
    
    virtual void MoveOffsetWithinWindow(uint32_t _offset){} // request to move visual offset to an approximate amount

    /**
     * Scroll to specified offset, moving window if needed.
     * Line with _offset bytes should be visible after.
     */
    virtual void ScrollToByteOffset(uint64_t _offset){}
    
    
    virtual void HandleVerticalScroll(double _pos){} // move file window if needed
    
    virtual bool NeedsVerticalScroller(){ return true;};
    
    // drawing
    virtual void DoDraw(CGContextRef _context, NSRect _dirty_rect){}
    
    // user input handlers
    virtual void OnUpArrow() {}
    virtual void OnDownArrow() {}
    virtual void OnPageDown() {}
    virtual void OnPageUp() {}    
    virtual void OnLeftArrow(){}
    virtual void OnRightArrow(){}
    virtual void OnMouseDown(NSEvent *_event){}
    virtual void OnWordWrappingChanged(){}
};

#endif


@protocol NCViewerImplementationProtocol <NSObject>
@optional

/**
 * Informs that the backend content was changed, presumably by its momement.
 */
- (void)backendContentHasChanged;

/**
 * Non-binding request to show content located at the '_offset' position within the file.
 */
- (bool)scrollToGlobalBytesOffset:(int64_t)_offset;

/**
 * Informs that the selection was changed.
 */
- (void) selectionHasChanged;

/**
 * Informs that the line wrapping setting has changed.
 */
- (void) lineWrappingHasChanged;

/**
 * Informs that visual theme provided for the implementation has changed.
 */
- (void) themeHasChanged;

@end
