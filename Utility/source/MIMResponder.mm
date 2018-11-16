// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/MIMResponder.h>
#include <Utility/ObjCpp.h>

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
}

@end
