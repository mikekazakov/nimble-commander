#include "AppStoreHelper.h"


@implementation AppStoreHelper
{
    SKProductsRequest *m_ProductRequest;
}
//info.filesmanager.Files-Lite
//info.filesmanager.Files-Lite
//@"com.magnumbytes.nimblecommander.paid_features"
- (id) init
{
    if(self = [super init]) {
        m_ProductRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:@"com.magnumbytes.nimblecommander.paid_features"]];
        m_ProductRequest.delegate = self;
        [m_ProductRequest start];
        
        
        
    
    
    }
    return self;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    int a = 10;
    
    
}

- (void)request:(SKRequest *)request didFailWithError:(nullable NSError *)error
{
    int a = 10;
    
    
}

@end