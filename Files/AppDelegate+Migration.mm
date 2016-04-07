#include "3rd_party/NSFileManager+DirectoryLocations.h"
#include "Config.h"
#include "AppDelegate+Migration.h"
#include "ActivationManager.h"

@implementation AppDelegate (Migration)

- (void) migrateAppSupport_1_1_1_to_1_1_2
{
    auto fm = NSFileManager.defaultManager;
    NSString *my_bundle_name = NSBundle.mainBundle.infoDictionary[@"CFBundleExecutable"];
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if( paths.count == 0 )
        return; // something is _very_ broken
    
    NSString *target_path = [paths[0] stringByAppendingPathComponent:my_bundle_name];
    if( [fm fileExistsAtPath:target_path] )
        return; // we're done
  
    NSString *old_bundle_name = @"";
    if( ActivationManager::Type() == ActivationManager::Distribution::Paid )
        old_bundle_name = @"Files Pro";
    else if( ActivationManager::Type() == ActivationManager::Distribution::Free )
        old_bundle_name = @"Files Lite";
    else
        old_bundle_name = @"Files";
    
    NSString *source_path = [paths[0] stringByAppendingPathComponent:old_bundle_name];
    BOOL source_path_is_dir = false;
    if( ![fm fileExistsAtPath:source_path isDirectory:&source_path_is_dir] || !source_path_is_dir )
        return; // we're done
    
    [fm copyItemAtPath:source_path toPath:target_path error:nil];
}

@end
