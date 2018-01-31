#include <Utility/MIMResponder.h>
#include <Utility/ObjCpp.h>

//@implementation MIMResponder
//
//+ (void) setNextResponder:(NSResponder*)_next_responder
//                forObject:(NSResponder<MIMResponder>*)_obj
//{
//    if( _obj == nil )
//        return;
//    
//    const auto current_nr = _obj.nextResponder;
//    if( [current_nr respondsToSelector:@selector(setNextMIMResponder:)] ) {
//        
//        
//        
//        
//    }
//    else {
//        
//        
//        
//    }
//    
////    if( objc_cast<>(<#id from#>)  )
//    
//    
//    
//}
//
////+ (void) setNextMIMResponder:(id<MIMResponder>)_next_mim_responder forObject:(id)_obj
////{
////    
////    
////}
//
//
//@end


@implementation AttachedResponder
{
    AttachedResponder *m_Next;
}

- (AttachedResponder*)nextAttachedResponder
{
    return m_Next;
}

- (void)setNextResponder:(NSResponder *)nextResponder
{
    if( m_Next  ) {
        assert( self.nextResponder == m_Next );
        [m_Next setNextResponder:nextResponder];
    }
    else {
        [super setNextResponder:nextResponder];
        
    }
    
//    if( auto attached_responder = objc_cast<AttachedResponder>(self.nextResponder) ) {
//        [attached_responder setNextResponder:nextResponder];
//    }
//    else {
//        [super setNextResponder:nextResponder];
//    }
}


- (void)setNextAttachedResponder:(AttachedResponder *)nextAttachedResponder
{
    if( m_Next ) {
        assert( self.nextResponder == m_Next );
        [m_Next setNextAttachedResponder:nextAttachedResponder];
    }
    else {
        m_Next = nextAttachedResponder;
        auto current_responder = self.nextResponder;
        [super setNextResponder:nextAttachedResponder];
        [nextAttachedResponder setNextResponder:current_responder];
    }
    
    
//    if( auto attached_responder = objc_cast<AttachedResponder>(self.nextResponder) ) {
//        [attached_responder setNextAttachedResponder:nextAttachedResponder];
//    }
//    else {
//        auto current_responder = self.nextResponder;
//        [super setNextResponder:nextAttachedResponder];
//        [nextAttachedResponder setNextResponder:current_responder];
//    }
}

//- (void)setNextResponder:(NSResponder *)newNextResponder
//{
//    if( auto r = objc_cast<NSResponder>(self.delegate) ) {
//        r.nextResponder = newNextResponder;
//        return;
//    }
//    
//    [super setNextResponder:newNextResponder];
//}


//- (void) setDelegate:(id<PanelViewDelegate>)delegate
//{
//    m_Delegate = delegate;
//    if( auto r = objc_cast<NSResponder>(delegate) ) {
//        NSResponder *current = self.nextResponder;
//        super.nextResponder = r;
//        r.nextResponder = current;
//    }
//}

@end

//- (void)setNextResponder:(NSResponder *)nextResponder;
