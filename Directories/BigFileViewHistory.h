//
//  BigFileViewHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 29.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BigFileView.h"

@interface BigFileViewHistoryEntry : NSObject<NSCoding> {
@public    
    NSString *path;
    NSDate   *last_viewed;
    uint64_t position;
    bool    wrapping;
    BigFileViewModes view_mode;
    int encoding;
    CFRange selection;
}
@end

struct BigFileViewHistoryOptions
{
    bool encoding;
    bool mode;
    bool position;
    bool wrapping;
    bool selection;
};

@interface BigFileViewHistory : NSObject


+ (BigFileViewHistory*) sharedHistory;
- (BigFileViewHistoryEntry*) FindEntryByPath: (NSString *)_path;
- (void) InsertEntry: (BigFileViewHistoryEntry*) _entry; // will overwrite existing entry with same path

+ (BigFileViewHistoryOptions) HistoryOptions;
+ (bool) HistoryEnabled;

@end
