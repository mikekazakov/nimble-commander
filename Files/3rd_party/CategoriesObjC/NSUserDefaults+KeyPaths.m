#import "NSUserDefaults+KeyPaths.h"
#import "NSArray+SSYMutations.h"
#import "NSDictionary+SimpleMutations.h"


@implementation NSUserDefaults (KeyPaths)

- (id)valueForKeyPathArray:(NSArray*)keyPathArray {
	// Don't use componentsJoinedByString:@"." because it is legal
	// for a key path to contain a dot/period.
	id obj = self ;
	for(id key in keyPathArray) {
		if (![obj respondsToSelector:@selector(objectForKey:)]) {
			// Corrupt pref?
			return nil ;
		}
		obj = [(NSDictionary*)obj objectForKey:key] ;
	}
	
	return obj;
}

- (void)setValue:(id)value
 forKeyPathArray:(NSArray*)keyArray {
	NSInteger N = [keyArray count] ;
	if (!value || (N < 1)) {
		return ;
	}	
	
	NSMutableArray* dics = [[NSMutableArray alloc] init] ;
	id object = self ;
	id nextObject = value ;
	NSInteger i ;
	for (i=0; i<N-1; i++) {
		NSString* key = [keyArray objectAtIndex:i] ;
		object = [(NSDictionary*)object objectForKey:key] ;
		if ([object isKindOfClass:[NSDictionary class]]) {
			// Required dictionary already exists.  Stash it for later.
			[dics addObject:object] ;
		}
		else {
			// Dictionary does not exist staring at this level,
			// (or preferences are corrupt and we didn't get a
			// dictionary where one was expected.  In this case,
			// we will, I believe, later, silently overwrite the
			// corrupt object)
			// Make one, from the bottom up, starting with 
			// the value and the last key in keyArray.
			// Then break out of the loop.
			NSInteger j  ;
			nextObject = value ;
			if (nextObject) {   // if () added as bug fix in BookMacster 1.14.4
                for (j=N-1; j>i; j--) {
                    NSString* aKey = [keyArray objectAtIndex:j] ;
                    nextObject = [NSDictionary dictionaryWithObject:nextObject
                                                             forKey:aKey] ;
                }
            }
			
			break ;
		}
	}
	
	// Reverse-enumerate through the dictionaries, starting at
	// the inside and setting little dictionaries as objects
	// inside the bigger dictionaries
	NSEnumerator* e = [dics reverseObjectEnumerator] ;
	NSMutableDictionary* copy ;
	for (NSDictionary* dic in e) {
		copy = [dic mutableCopy] ;
		[copy setObject:nextObject
				 forKey:[keyArray objectAtIndex:i]] ;
		nextObject = copy;
		i-- ;
	}
	
	if (nextObject) {  // if() added as bug fix added in BookMaster 1.14.4
        [self setObject:nextObject
                 forKey:[keyArray objectAtIndex:0]] ;
    }
}

- (void)setValue:(id)value
	  forKeyPath:(NSString*)keyPath {
	NSArray* keyPathArray = [keyPath componentsSeparatedByString:@"."] ;
	[self setValue:value forKeyPathArray:keyPathArray] ;
}

-      (void)addObject:(id)object
 toArrayAtKeyPathArray:(NSArray*)keyPathArray {
	NSArray* array = [self valueForKeyPathArray:keyPathArray] ;
	if (array) {
		array = [array arrayByAddingObject:object] ;
	}
	else {
		array = [NSArray arrayWithObject:object] ;
	}
	
	[self setValue:array
   forKeyPathArray:keyPathArray] ;
}

-      (void)addObject:(id)object
	  toArrayAtKey:(NSString*)key {
	NSArray* keyPathArray = [NSArray arrayWithObject:key] ;
	[self addObject:object toArrayAtKeyPathArray:keyPathArray] ;
}

- (void)addUniqueObject:(id)object
  toArrayAtKeyPathArray:(NSArray*)keyPathArray {
	NSArray* array = [self valueForKeyPathArray:keyPathArray] ;
	if (array) {
		array = [array arrayByAddingUniqueObject:object] ;
	}
	else {
		array = [NSArray arrayWithObject:object] ;
	}
	
	[self setValue:array
   forKeyPathArray:keyPathArray] ;
}

- (void)addUniqueObject:(id)object
	   toArrayAtKey:(NSString*)key {
	NSArray* keyPathArray = [NSArray arrayWithObject:key] ;
	[self addUniqueObject:object toArrayAtKeyPathArray:keyPathArray] ;
}

-     (void)removeObject:(id)object
 fromArrayAtKeyPathArray:(NSArray*)keyPathArray {
	NSArray* array = [self valueForKeyPathArray:keyPathArray] ;
	if (array) {
		array = [array arrayByRemovingObject:object] ;
		[self setValue:array
		forKeyPathArray:keyPathArray] ;
	}
	else {
		// The array doesn't exist.  Don't do anything.
	}
}

- (void)removeObject:(id)object
      fromArrayAtKey:(NSString*)key {
	NSArray* keyPathArray = [NSArray arrayWithObject:key] ;
	[self removeObject:object fromArrayAtKeyPathArray:keyPathArray] ;
}

-             (void)removeKey:(id)key
 fromDictionaryAtKeyPathArray:(NSArray*)keyPathArray {
	NSDictionary* dictionary = [self valueForKeyPathArray:keyPathArray] ;
	if (dictionary) {
		dictionary = [dictionary dictionaryBySettingValue:nil
												   forKey:key] ;
		[self setValue:dictionary
		forKeyPathArray:keyPathArray] ;
	}
	else {
		// The dictionary doesn't exist.  Don't do anything.
	}
}

-     (void)removeKey:(id)innerKey
  fromDictionaryAtKey:(NSString*)key {
	NSArray* keyPathArray = [NSArray arrayWithObject:key] ;
	[self removeKey:innerKey fromDictionaryAtKeyPathArray:keyPathArray] ;
}

- (void)incrementIntValueForKey:(id)innerKey
		  inDictionaryAtKeyPath:(id)outerKeyPath {
	NSString* keyPath = [NSString stringWithFormat:
						 @"%@.%@",
						 outerKeyPath,
						 innerKey] ;
	NSNumber* number = [self valueForKeyPath:keyPath] ;
	NSInteger value = 0 ;
	// We are careful since user defaults may be corrupted.
	if ([number respondsToSelector:@selector(integerValue)]) {
		value = [number integerValue] ;
	}
		
	value++ ;
	
	number = [NSNumber numberWithInteger:value] ;
	
	[self setValue:number
		forKeyPath:keyPath] ;
}




@end