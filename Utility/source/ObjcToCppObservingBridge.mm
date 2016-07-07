//
//  ObjcToCppObservingBridge.m
//  Files
//
//  Created by Michael G. Kazakov on 27.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/ObjcToCppObservingBridge.h>
#include <Utility/NSObject+MassObserving.h>

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

+ (instancetype) bridgeWithHandler:(ObjcToCppObservingBridge_Handler)_handler object:(void *)_obj
{
    ObjcToCppObservingBridge *t = [ObjcToCppObservingBridge alloc];
    return [t initWithHandler:_handler object:_obj];
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
    m_ObservingKeyPaths = @[keyPath];
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

@implementation ObjcToCppObservingBlockBridge
{
    void                            (^m_Block)(NSString *_key_path, id _objc_object, NSDictionary *_changed);
    __weak NSObject                  *m_ObjcObject;
    NSArray                          *m_ObservingKeyPaths;
}

- (id) initWithObject:(NSObject*) _object
           forKeyPath:(NSString *) _key_path
              options:(NSKeyValueObservingOptions) _options
                block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block
{
    self = [super init];
    
    if(self) {
        m_ObjcObject = _object;
        m_ObservingKeyPaths = @[_key_path];
        m_Block = _block;
        [m_ObjcObject addObserver:self forKeyPath:_key_path options:_options context:nil];
    }
    return self;
}

- (id) initWithObject:(NSObject*) _object
          forKeyPaths:(NSArray *) _key_paths
              options:(NSKeyValueObservingOptions) _options
                block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block
{
    self = [super init];
    
    if(self) {
        m_ObjcObject = _object;
        m_ObservingKeyPaths = _key_paths;
        m_Block = _block;
        [m_ObjcObject addObserver:self forKeyPaths:_key_paths options:_options context:nil];
    }
    return self;
}

- (void) dealloc
{
    [self stopObserving];
}

+ (instancetype) bridgeWithObject:(NSObject*) _object
                       forKeyPath:(NSString *) _key_path
                          options:(NSKeyValueObservingOptions)_options
                            block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block
{
    return [[ObjcToCppObservingBlockBridge alloc] initWithObject:_object
                                                      forKeyPath:_key_path
                                                         options:_options
                                                           block:_block];
}

+ (instancetype) bridgeWithObject:(NSObject*) _object
                      forKeyPaths:(NSArray *) _key_paths
                          options:(NSKeyValueObservingOptions) _options
                            block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block
{
    return [[ObjcToCppObservingBlockBridge alloc] initWithObject:_object
                                                     forKeyPaths:_key_paths
                                                         options:_options
                                                           block:_block];
}

- (void) stopObserving
{
    [m_ObjcObject removeObserver:self forKeyPaths:m_ObservingKeyPaths];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(m_Block)
        m_Block(keyPath, object, change);
}

@end
