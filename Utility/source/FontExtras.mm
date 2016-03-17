#include <string>
#include <Utility/FontExtras.h>

using namespace std;

@implementation NSFont (StringDescription)

+ (NSFont*) fontWithStringDescription:(NSString*)_description
{
    if( !_description )
        return nil;
    
    NSArray *arr = [_description componentsSeparatedByString:@","];
    if( !arr || arr.count != 2 )
        return nil;
    
    NSString *family = arr[0];
    NSString *size = [arr[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [NSFont fontWithName:family size:size.intValue];
}

- (NSString*) toStringDescription
{
    return [NSString stringWithFormat:@"%@, %s",
            self.fontName,
            to_string(int(floor(self.pointSize + 0.5))).c_str()
            ];
}

@end