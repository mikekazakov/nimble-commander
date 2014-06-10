#import <Cocoa/Cocoa.h>


/*!
 @brief   NSUserDefaults can read values from nested dictionaries
 with -[NSObject valueForKeyPath:], but not set such values.&nbsp; 
 This category adds the missing setValue:forKeyPath: method, and
 methods to mutate arrays located down key paths.&nbsp;  Each method
 also has a companion which takes a "key path array", which is a
 an array of string keys, instead of a key path, which is an 
 equivalent dot-separated string.
 
 WARNING: With power comes danger.  For example, with the
 "keyPathArray" methods, if your array is terminated by an
 unexpected nil, you could inadvertantly overwrite a parent dictionary
 with an array, for example.&nbsp; This will corrupt the user's
 preferences and lose the original preferences.&nbsp; Review your code
 carefully or at least use some NSAssert() to stop such corruption.
 
 Be careful that none of the elements of your key paths contain @"." !!
 Once upon a time, I had defined more methods with arguments:
 *  toArrayAtKeyPath:(NSString*)keyPath
 *  fromArrayAtKeyPath:(NSString*)keyPath
 *  fromArrayAtKeyPath:(NSString*)keyPath
 *  fromDictionaryAtKeyPath:(NSString*)keyPath
 which derived key path arrays from the key paths by using
 -componentsSeparatedByString:@".".  However these methods proved
 troublesome since keys themselves can include period/dots.
 If you need to dig down more than one level of keys,
 be safe and use the keyPathArray: methods instead!!
 
 ANOTHER WARNING: There seems to be a bug in NSUserDefaults
 in that NSNumber objects may not be keys of dictionaries.
 */
@interface NSUserDefaults (KeyPaths)

/*!
 @brief    A wrapper around -valueForKeyPath: which changes the parameter
 to be a key path array, instead of a dot-separated string of keys.
*/
- (id)valueForKeyPathArray:(NSArray*)keyPathArray ;

/*!
 @details  This method is a no-op oif value is nil.  That could be changed, as
 I have done in -[NSMutableDictionary(KeyPaths) setValue:forKeyPathArray:].
 However, since I use this method in about 50 places, that would take a lot
 of code review.
*/
- (void)setValue:(id)value
 forKeyPathArray:(NSArray*)keyPathArray ;

/*!
 @brief    Sets a value for the given keyPath in the receiver,
 creating dictionaries as needed if they do not exist, and inserting
 values into existing dictionaries if they do exist.

 @details  Note that this is an override of the NSObject method.  
 The opposite method, -valueForKeyPath:, is also provided by
 NSObject, but it works as expected.
 @param    value  
 @param    keyPath  
*/
- (void)setValue:(id)value
	  forKeyPath:(NSString*)keyPath ;

-      (void)addObject:(id)object
 toArrayAtKeyPathArray:(NSArray*)keyPathArray ;

- (void)addObject:(id)object
     toArrayAtKey:(NSString*)key ;

- (void)addUniqueObject:(id)object
  toArrayAtKeyPathArray:(NSArray*)keyPathArray ;

- (void)addUniqueObject:(id)object
           toArrayAtKey:(NSString*)key ;

-      (void)removeObject:(id)object
  fromArrayAtKeyPathArray:(NSArray*)keyPathArray ;

- (void)removeObject:(id)object
      fromArrayAtKey:(NSString*)key ;

-              (void)removeKey:(id)object
  fromDictionaryAtKeyPathArray:(NSArray*)keyPathArray ;

-     (void)removeKey:(id)innerKey
  fromDictionaryAtKey:(NSString*)key ;

- (void)incrementIntValueForKey:(id)innerKey
		  inDictionaryAtKeyPath:(id)outerKey ;

@end
