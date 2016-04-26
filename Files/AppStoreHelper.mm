#include "AppStoreHelper.h"

static const auto g_ProFeaturesInAppID = @"com.magnumbytes.nimblecommander.paid_features";

@implementation AppStoreHelper
{
    SKProductsRequest   *m_ProductRequest;
    SKProduct           *m_ProFeaturesProduct;
}

- (id) init
{
    if(self = [super init]) {
        [SKPaymentQueue.defaultQueue addTransactionObserver:self];
        
        m_ProductRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:g_ProFeaturesInAppID]];
        m_ProductRequest.delegate = self;
        [m_ProductRequest start];
        
        
    }
    return self;
}

// background thread
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    int a = 10;
//    NSArray<SKProduct *> *products
    
    for( SKProduct* p in response.products ) {
        if( [p.productIdentifier isEqualToString:g_ProFeaturesInAppID] )
            m_ProFeaturesProduct = p;
        
        NSLog(@"%@ %@ %@", p.productIdentifier, p.localizedTitle, p.price);
    }
    
    
//    if( m_ProFeaturesProduct ) {
//        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
//        nf.numberStyle = NSNumberFormatterCurrencyStyle;
//        nf.locale = m_ProFeaturesProduct.priceLocale;
//        NSString *price = [nf stringFromNumber:m_ProFeaturesProduct.price];
//        NSLog(@"%@", price);
//        
//        
//     
//        
//        SKPayment *payment = [SKPayment paymentWithProduct:m_ProFeaturesProduct];
//        [SKPaymentQueue.defaultQueue addPayment:payment];
//        
//    }
}

// background thread
- (void)request:(SKRequest *)request didFailWithError:(nullable NSError *)error
{
    int a = 10;
    
    
}

// background thread
- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for( SKPaymentTransaction *pt in transactions ) {
        switch (pt.transactionState) {
//            case SKPaymentTransactionStatePurchasing:;
//                break;
            case SKPaymentTransactionStatePurchased:;
                [queue finishTransaction:pt];
                break;
            case SKPaymentTransactionStateFailed:
                [queue finishTransaction:pt];
                break;
            case SKPaymentTransactionStateRestored:;
                [queue finishTransaction:pt];
                break;
            case SKPaymentTransactionStateDeferred:;
                [queue finishTransaction:pt];
                break;
            default:
                break;
        }
        
    }
    
    
    
}

@end
