// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ObjCpp.h>
#include <Foundation/Foundation.h>

const char *objc_class_c_str(id _object) noexcept
{
    if( _object == nil )
        return "";
    
    Class cl = [_object class];
    if( cl == nil )
        return "";
    
    NSString *ns_str = NSStringFromClass(cl);
    if( ns_str == nil )
        return "";
        
    return [ns_str UTF8String];
}
