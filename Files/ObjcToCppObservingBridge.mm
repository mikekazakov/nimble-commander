//
//  ObjcToCppObservingBridge.m
//  Files
//
//  Created by Michael G. Kazakov on 27.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "ObjcToCppObservingBridge.h"
#import "Common.h"

@implementation ObjcToCppObservingBridge
{
    ObjcToCppObservingBridge_Handler m_Handler;
    void                             *m_CppObject;
    NSObject                         *m_ObjcObject;
    NSArray                          *m_ObservingKeyPaths;
}

- (id) initWithHandler:(ObjcToCppObservingBridge_Handler)_handler object:(void *)_obj
{
    self = [super init];
    if(self)
    {
        m_Handler = _handler;
        m_CppObject = _obj;
    }
    return self;
}

- (void) dealloc
{
    [self stopObserving];
}

- (void) stopObserving
{
    if(m_ObjcObject)
        [m_ObjcObject removeObserver:self forKeyPaths:m_ObservingKeyPaths];
}

- (void) observeChangesInObject:(NSObject*) _object
                     forKeyPath:(NSString *)keyPath
                        options:(NSKeyValueObservingOptions)options
                        context:(void *)context
{
    [self stopObserving];
    m_ObservingKeyPaths = [NSArray arrayWithObject:keyPath];
    m_ObjcObject = _object;
    [m_ObjcObject addObserver:self forKeyPath:keyPath options:options context:context];
}

- (void) observeChangesInObject:(NSObject*) _object
                    forKeyPaths:(NSArray*) keyPaths
                        options:(NSKeyValueObservingOptions)options
                        context:(void *)context
{
    [self stopObserving];
    m_ObservingKeyPaths = keyPaths;
    m_ObjcObject = _object;
    [m_ObjcObject addObserver:self forKeyPaths:m_ObservingKeyPaths options:options context:context];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    m_Handler(m_CppObject, keyPath, object, change, context);
}

@end
