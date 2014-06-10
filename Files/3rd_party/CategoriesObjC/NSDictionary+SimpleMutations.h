#import <Cocoa/Cocoa.h>


@interface NSDictionary (SimpleMutations)

/*!
 @brief    Returns a new dictionary, equal to the receiver
 except with a single key/value pair updated or removed.

 @details  Convenience method for mutating a single key/value
 pair in a dictionary without having to make a mutable copy,
 blah, blah...  Of course, if you have many mutations to make
 it would be more efficient to make a mutable copy and then do
 all your mutations at once in the normal way.
 @param    value  The new value for the key.  May be nil.
 If it is nil, the key is removed from the receiver if it exists.
 If it is non-nil and the key already exists, the existing
 value is overwritten with the new value
 @param    key  The key to be mutated.  May be nil; this method
 simply returns a copy of the receiver.
 @result   The new dictionary
*/
- (NSDictionary*)dictionaryBySettingValue:(id)value
								   forKey:(id)key ;

/*!
 @brief    Returns a new dictionary, equal to the receiver
 except with a single key/value removed.
 
 @details  Invokes dictionaryBySettingValue:forKey: with value = nil
 */
- (NSDictionary*)dictionaryByRemovingObjectForKey:(id)key ;

/*!
 @brief    Returns a new dictionary, equal to the receiver
 except with additional entries from another dictionary.
 
 @details  Convenience method combining two dictionaries.
 If an entry in otherDic already exists in the receiver,
 the existing value is overwritten with the value from
 otherDic
 @param    otherDic  The other dictionary from which entries
 will be copied.  May be nil or empty; in these cases the
 result is simply a copy of the receiver.
 @result   The new dictionary
 */
- (NSDictionary*)dictionaryByAddingEntriesFromDictionary:(NSDictionary*)otherDic ;

/*!
 @brief    Same as dictionaryByAddingEntriesFromDictionary:
 except that no existing entries in the receiver are overwritten.

 @details  If otherDic contains an entry whose key already exists
 in the receiver, that entry is ignored.
 @param    otherDic  The other dictionary from which entries
 will be copied.  May be nil or empty; in these cases the
 result is simply a copy of the receiver.
 @result   The new dictionary
 */
- (NSDictionary*)dictionaryByAppendingEntriesFromDictionary:(NSDictionary*)otherDic ;

/*!
 @brief    Given a dictionary of existing additional entries, a set of existing
 keys to be deleted, a dictionary new additional entries, and a set of
 new keys to be deleted, mutates the existing dictionary and set to reflect the
 new additions and deletions.
 
 @details  First, checks newAdditions and newDeletions for common
 members which cancel each other out, and if any such are found, removes
 them from both collections.  Then, for each remaining new addition, if
 a deletion of the same key exists, removes it ("cancels it out"),
 and if not, adds the entry to the existing additions.  Finally, for each
 remaining new deletion, if a addition of the same object exists,
 removes it ("cancels it out"), and if not, adds it to the existing
 deletions. */
+ (void)mutateAdditions:(NSMutableDictionary*)additions
			  deletions:(NSMutableSet*)deletions
		   newAdditions:(NSMutableDictionary*)newAdditions
		   newDeletions:(NSMutableSet*)newDeletions ;

@end
