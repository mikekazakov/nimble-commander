//
//  ObjcToCppObservingBridge.h
//  Files
//
//  Created by Michael G. Kazakov on 27.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (*ObjcToCppObservingBridge_Handler)(void *_cpp_object,
                                                NSString *_key_path,
                                                id _objc_object,
                                                NSDictionary *_changed,
                                                void *_context);

@interface ObjcToCppObservingBridge : NSObject

+ (instancetype) bridgeWithHandler:(ObjcToCppObservingBridge_Handler)_handler object:(void *)_obj;
- (id) initWithHandler:(ObjcToCppObservingBridge_Handler)_handler object:(void *)_obj;

- (void) observeChangesInObject:(NSObject*) _object
                     forKeyPath:(NSString *)keyPath
                        options:(NSKeyValueObservingOptions)options
                        context:(void *)context;

- (void) observeChangesInObject:(NSObject*) _object
                     forKeyPaths:(NSArray*) keyPaths
                        options:(NSKeyValueObservingOptions)options
                        context:(void *)context;
@end

@interface ObjcToCppObservingBlockBridge : NSObject

- (id) initWithObject:(NSObject*) _object
           forKeyPath:(NSString *) _key_path
              options:(NSKeyValueObservingOptions) _options
                block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block;

- (id) initWithObject:(NSObject*) _object
          forKeyPaths:(NSArray *) _key_paths
              options:(NSKeyValueObservingOptions) _options
                block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block;

+ (instancetype) bridgeWithObject:(NSObject*) _object
                       forKeyPath:(NSString *) _key_path
                          options:(NSKeyValueObservingOptions) _options
                            block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block;

+ (instancetype) bridgeWithObject:(NSObject*) _object
                      forKeyPaths:(NSArray *) _key_paths
                          options:(NSKeyValueObservingOptions) _options
                            block:(void(^)(NSString *_key_path, id _objc_object, NSDictionary *_changed)) _block;

@end
