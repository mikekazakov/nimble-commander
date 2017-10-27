// Copyright (C) 2014-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/dispatch_cpp.h>
#include <Utility/SheetController.h>

using namespace std;
using namespace std::chrono;

@implementation SheetController
{
    __strong SheetController *m_Self;
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
    }
    return self;
}

- (void) beginSheetForWindow:(NSWindow*)_wnd
{
    [self beginSheetForWindow:_wnd completionHandler:^(NSModalResponse returnCode) {}];
}

- (void) beginSheetForWindow:(NSWindow*)_wnd
           completionHandler:(void (^)(NSModalResponse returnCode))_handler
{
    if(!dispatch_is_main_queue()) {
        dispatch_to_main_queue([=]{
            [self beginSheetForWindow:_wnd completionHandler:_handler];
        });
        return;
    }
    
    assert(_handler != nil);
    m_Self = self;
    
    [_wnd beginSheet:self.window completionHandler:_handler];
}

- (void) endSheet:(NSModalResponse)returnCode
{
    bool release_self = m_Self != nil;
    
    [self.window.sheetParent endSheet:self.window returnCode:returnCode];
    
    if(release_self)
        dispatch_to_main_queue_after(1ms, [=]{
            m_Self = nil;
        });
}

@end
