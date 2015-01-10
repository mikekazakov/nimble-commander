//
//  NewVersionChecker.mm
//  Files
//
//  Created by Michael G. Kazakov on 11.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/sparkle/SUStandardVersionComparator.h"
#import "NewVersionChecker.h"
#import "Common.h"

/* plist should have the following form:

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
 <dict>
  <key>Version</key>
  <string>0.4.5</string>
  <key>Build</key>
  <string>500</string>
 </dict>
</plist>
*/

static NSString *g_URLCheckString = @"http://filesmanager.info/downloads/latest.plist";
static NSString *g_URLSiteString = @"http://filesmanager.info/";
static NSString *g_DefKey = @"CommonNewVersionCheckNextDate";

static void GotNewVersion()
{
    // say to user about new version
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"A new version of Files is available!", "Informing user that a new version is available");
    alert.informativeText = NSLocalizedString(@"Would you like to visit a website?", "Asking user if he wants to visit a website for update");
    alert.alertStyle = NSInformationalAlertStyle;
    [alert addButtonWithTitle:NSLocalizedString(@"OK","")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [[alert.buttons objectAtIndex:1] setKeyEquivalent:@"\E"];
    dispatch_sync(dispatch_get_main_queue(), ^{
        if(alert.runModal == NSAlertFirstButtonReturn)
        {
            // go to website
            [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:g_URLSiteString]];
        }
        else
        {
            // user don't want to go to website - set next check time to +1 week
            NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
            NSDate *next_check = [NSDate dateWithTimeIntervalSinceNow:60*60*24*7];
            [defaults setObject:[NSArchiver archivedDataWithRootObject:next_check] forKey:g_DefKey];
        }
    });
}

static void CheckForNewVersion()
{
    NSURL *url = [NSURL URLWithString:g_URLCheckString];
    if(!url)
        return;

    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    NSURLResponse *resp;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:0];
    if(!data)
        return;
    
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:0 error:0];
    if([obj isKindOfClass:NSDictionary.class])
    {
        NSDictionary *dict = obj;
        id version_id = [dict objectForKey:@"Version"];
        id build_id = [dict objectForKey:@"Build"];
        if(version_id != nil &&
           build_id != nil &&
           [version_id isKindOfClass:NSString.class] &&
           [build_id isKindOfClass:NSString.class] )
        {
            NSString *version_str = version_id;
            NSString *build_str = build_id;
            NSString *current_build = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"];
            NSString *current_ver = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"];
            if(current_build && current_ver)
            {
                NSNumberFormatter *f = [NSNumberFormatter new];
                f.numberStyle = NSNumberFormatterDecimalStyle;
                NSNumber *current_build_num = [f numberFromString:current_build];
                NSNumber *build_num = [f numberFromString:build_str];
                if(current_build_num && build_num)
                {
                    if([build_num compare:current_build_num] == NSOrderedDescending ||
                       [SUStandardVersionComparator.defaultComparator compareVersion:version_str
                                                                           toVersion:current_ver] == NSOrderedDescending
                       )
                    {
                        GotNewVersion();
                    }
                }
            }
        }
    }
}

void NewVersionChecker::Go()
{
    // go background async immediately, so don't pause startup process for any milliseconds
    dispatch_to_background([]{
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        if(NSData *d = [defaults dataForKey:g_DefKey])
        {
            // if check date is less than current date - GoAsync and set next check date to tomorrow
            NSDate *check_date = (NSDate*)[NSUnarchiver unarchiveObjectWithData:d];
            if([check_date compare:NSDate.date] == NSOrderedAscending)
            {
                NSDate *next_check = [NSDate dateWithTimeIntervalSinceNow:60*60*24]; // current date + 1 day
                [defaults setObject:[NSArchiver archivedDataWithRootObject:next_check] forKey:g_DefKey];
            
                // actual I/O goes here
                CheckForNewVersion();
            }
        }
        else
        {
            // if there's no check date - set current date as check data and quit
            [defaults setObject:[NSArchiver archivedDataWithRootObject:NSDate.date] forKey:g_DefKey];
        }
        
        dispatch_after(24h + 1s, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), []{
                Go();
                }
            );
    });
}
