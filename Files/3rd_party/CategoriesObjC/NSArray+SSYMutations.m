#import "NSArray+SSYMutations.h"


@implementation NSArray (SSYMutations)

- (NSArray*)arrayByRemovingObject:(id)object  {
	NSMutableArray* mutant = [self mutableCopy] ;
	[mutant removeObject:object] ;
	NSArray* newArray = [NSArray arrayWithArray:mutant] ;
	
	return newArray ;
}

- (NSArray*)arrayByRemovingObjectsFromSet:(NSSet*)set  {
	NSMutableArray* mutant = [self mutableCopy] ;
	for (id object in set) {
        [mutant removeObject:object] ;
    }
	NSArray* newArray = [NSArray arrayWithArray:mutant] ;
	
	return newArray ;
}

- (NSArray*)arrayByInsertingObject:(id)object
						   atIndex:(NSInteger)index {
	NSArray* answer ;
	if (object) {
		NSMutableArray* mutant = [self mutableCopy] ;
		[mutant insertObject:object
					 atIndex:index] ;
		answer = [NSArray arrayWithArray:mutant] ;
	}
	else {
		answer = self ;
	}
	
	return answer ;
}

- (NSArray*)arrayByRemovingObjectAtIndex:(NSUInteger)index  {
	NSMutableArray* mutant = [self mutableCopy] ;
	[mutant removeObjectAtIndex:index] ;
	NSArray* newArray = [NSArray arrayWithArray:mutant] ;
	
	return newArray ;
}

- (NSArray*)arrayByAddingUniqueObject:(id)object {
	NSArray* array ;
	if ([self indexOfObject:object] == NSNotFound) {
		array = [self arrayByAddingObject:object] ;
	}
	else {
		array = self ;
	}
	
	return array ;
}

- (NSArray*)arrayByAddingUniqueObjectsFromArray:(NSArray*)array {
	if (!array) {
		return self ;
	}
    
	NSMutableArray* newArray = [self mutableCopy] ;
	for (id object in array) {
		if ([self indexOfObject:object] == NSNotFound) {
			[newArray addObject:object] ;
		}
	}
	
	NSArray* answer = [newArray copy] ;
	return answer;
}

- (NSArray*)arrayByRemovingObjectsEqualPerSelector:(SEL)isEqualSelector {
    assert(0); // commented out strange code
    return nil;
#if 0
	NSMutableArray* keepers = [[NSMutableArray alloc] init] ;
	for (id object in self) {
		BOOL isUnique = YES ;
		for (id uniqueObject in keepers) {
			if ([object performSelector:isEqualSelector
							 withObject:uniqueObject]) {
				isUnique = NO ;
				break ;
			}
		}
		
		if (isUnique) {
			[keepers addObject:object] ;
		}
	}
	
	NSArray* answer = [keepers copy] ;
	
	return answer;
#endif
}

- (NSArray*)arrayByRemovingEqualObjects {
	NSMutableArray* mutableCopy = [self mutableCopy] ;
    [mutableCopy removeEqualObjects] ;
    NSArray* copy = [mutableCopy copy] ;
	return copy;
}


- (NSArray*)arrayIntersectingCollection:(NSObject <NSFastEnumeration> *)collection {
	NSMutableIndexSet* keepers = [[NSMutableIndexSet alloc] init] ;
	for (id object in collection) {
		NSInteger index = [self indexOfObject:object] ;
		if (index != NSNotFound) {
			[keepers addIndex:index] ;
		}
	}
	
	NSArray* newArray = [self objectsAtIndexes:keepers] ;
	return newArray ;
}

- (NSArray*)arrayMinusCollection:(NSObject <NSFastEnumeration> *)collection {
	NSMutableArray* keepers = [self mutableCopy] ;
	for (id object in collection) {
		NSInteger index = [keepers indexOfObject:object] ;
		if (index != NSNotFound) {
			[keepers removeObjectAtIndex:index] ;
		}
	}
	
	NSArray* newArray = [keepers copy];
	return newArray ;
}

+ (void)mutateAdditions:(NSMutableArray*)additions
			  deletions:(NSMutableArray*)deletions
		   newAdditions:(NSCountedSet*)newAdditions
		   newDeletions:(NSCountedSet*)newDeletions {
	// A copy of a collection which we use to enumerate upon
	// so that we can simultaneously modify the copied collection…
	NSCountedSet* immuterator ;
    
	NSInteger index, nCancellations, i ;
	
	// Remove from newAdditions and newDeletions any members
	// in these new inputs which cancel one another out
	immuterator = [newAdditions copy] ;
	for (id object in immuterator) {
		id member = [newDeletions member:object] ;
		if (member) {
			nCancellations = MIN([newAdditions countForObject:object], [newDeletions countForObject:object]) ;
			for (i=0; i<nCancellations; i++) {
				[newAdditions removeObject:object] ;
				[newDeletions removeObject:member] ;
			}
		}
	}
	
	// Remove from newAdditions any which cancel out existing deletions,
	// and do the cancellation
	immuterator = [newAdditions copy] ;
	for (id object in immuterator) {
		// The following loop will cycle M times, where M is the count
		// of object in newAdditions, or the count of object in deletions,
		// whichever is less.  It's the same as the previous loop, except
		// you do it a little differently because one subject is an array
		// instead of a counted set
		for (i=0; i<[immuterator countForObject:object]; i++) {
			index = [deletions indexOfObject:object] ;
			if (index == NSNotFound) {
				break ;
			}
			[newAdditions removeObject:object] ;
			[deletions removeObjectAtIndex:index] ;
		}
	}

	// Add surviving new additions to existing additions
	for (id object in newAdditions) {
		for (i=0; i<[newAdditions countForObject:object]; i++) {
			[additions addObject:object] ;
		}
	}
	
	// Remove from newDeletions any which cancel out existing additions,
	// and do the cancellation
	immuterator = [newDeletions copy] ;
	for (id object in immuterator) {
		for (i=0; i<[immuterator countForObject:object]; i++) {
			index = [additions indexOfObject:object] ;
			if (index == NSNotFound) {
				break ;
			}
			[newDeletions removeObject:object] ;
			[additions removeObjectAtIndex:index] ;
		}
	}

	
	// Add surviving new deletions to existing deletions
	for (id object in newDeletions) {
		for (i=0; i<[newDeletions countForObject:object]; i++) {
			[deletions addObject:object] ;
		}
	}
}

@end


@implementation NSMutableArray (SSYMutations)

- (void)moveObject:(id)object
		   toIndex:(NSInteger)newIndex {
	NSInteger currentIndex = [self indexOfObject:object] ;
	if (currentIndex != NSNotFound) {
		id actualObject = [self objectAtIndex:currentIndex] ;
		[self removeObject:actualObject] ;
		newIndex = MIN(newIndex, [self count]) ;
		[self insertObject:actualObject
				   atIndex:newIndex] ;
	}
}

- (void)trimToStartIndex:(NSInteger)startIndex
				   count:(NSInteger)count {
	if (count < 1) {
		[self removeAllObjects] ;
	}
	else {
		NSRange deadRange ;
		
		// Remove lower range
		// Use the ? operator instead of MIN, because the two parameters are of different
		// types (NSInteger, NSUInteger) which causes MIN to behave unpredictably.
		NSInteger minLength = (startIndex < (NSInteger)[self count]) ? startIndex : [self count] ;
		NSInteger deadLength = MAX(minLength, 0) ;
		deadRange = NSMakeRange(0, deadLength) ;
		[self removeObjectsInRange:deadRange] ;
		
		// Remove upper range
		NSInteger excess = [self count] - count ;
		if (excess > 0) {
			deadRange = NSMakeRange(count, excess) ;
			[self removeObjectsInRange:deadRange] ;
		}
	}
}

- (void)removeEqualObjects {
	NSArray* copy = [self copy] ;
    NSInteger i = 0 ;
    NSInteger offset = 0 ;
	for (id object in copy) {
        NSInteger j = 0 ;
        for (id priorObject in copy) {
            if (j >= i) {
                // We only look for earlier objects
                break ;
            }
            if ([object isEqual:priorObject]) {
                NSInteger removeIndex = i - offset ;
                [self removeObjectAtIndex:removeIndex] ;
                offset++ ;
                break ;
            }
            j++ ;
        }
        
        i++ ;
	}
}

@end