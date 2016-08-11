//
//  BigFileViewHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 29.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma one

// TODO: remove this file after 1.1.5

@interface BigFileViewHistory : NSObject

//
//+ (BigFileViewHistory*) sharedHistory;
//- (BigFileViewHistoryEntry*) FindEntryByPath: (NSString *)_path;
//- (void) InsertEntry: (BigFileViewHistoryEntry*) _entry; // will overwrite existing entry with same path
//
//+ (BigFileViewHistoryOptions) HistoryOptions;
//+ (bool) HistoryEnabled;
//
//+ (bool) DeleteHistory;
//

+ (void) moveToNewHistory;

@end
