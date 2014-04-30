//
//  BigFileViewProtocol.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BigFileViewDataBackend.h"

@class BigFileView;

class BigFileViewImpl
{
public:
    
    virtual ~BigFileViewImpl(){};
    
    // information
    virtual uint32_t GetOffsetWithinWindow(){return 0;}; // offset of a first visible symbol (+/-)
    
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
