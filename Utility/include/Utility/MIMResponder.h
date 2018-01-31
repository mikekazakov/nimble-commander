#pragma once
#include <Cocoa/Cocoa.h>

//@protocol AttachableResponder<NSObject>

//@required

//- (void) setNextAttachedResponder:(NSResponder<NextAttachedResponder>*)_next_mim;


//@required 


//@end


@interface AttachedResponder : NSResponder


- (AttachedResponder*)nextAttachedResponder;

- (void)setNextResponder:(NSResponder *)nextResponder;
- (void)setNextAttachedResponder:(AttachedResponder *)nextAttachedResponder;

@end

//@interface MIMResponder : NSObject
//
//+ (void) setNextResponder:(NSResponder*)_next_responder
//                forObject:(NSResponder<MIMResponder>*)_obj;
////+ (void) setNextMIMResponder:(id<MIMResponder>)_next_mim_responder forObject:(id)_obj;
//
//@end
