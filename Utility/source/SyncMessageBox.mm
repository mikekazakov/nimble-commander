#include <AppKit/AppKit.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/SyncMessageBox.h>

void SyncMessageBoxUTF8(const char *_utf8_string)
{
    SyncMessageBoxNS([NSString stringWithUTF8String:_utf8_string]);
}

void SyncMessageBoxNS(NSString *_ns_string)
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText: _ns_string];
    
    if( dispatch_is_main_queue() )
        [alert runModal];
    else
        dispatch_sync(dispatch_get_main_queue(), ^{ [alert runModal]; } );
}
