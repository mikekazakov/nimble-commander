#include "AppStoreHelper.h"

static const auto g_ProFeaturesInAppID = @"com.magnumbytes.nimblecommander.paid_features";

string CFBundleGetAppStoreReceiptPath( CFBundleRef _bundle )
{
    if( !_bundle )
        return "";
    
    CFURLRef url = CFBundleCopyBundleURL( _bundle );
    if( !url )
        return "";
    
    NSBundle *bundle = [NSBundle bundleWithURL:(NSURL*)CFBridgingRelease(url)];
    if( !bundle )
        return "";
    
    return bundle.appStoreReceiptURL.fileSystemRepresentation;
}

@implementation AppStoreHelper
{
    SKProductsRequest                   *m_ProductRequest;
    SKProduct                           *m_ProFeaturesProduct;
    function<void(const string &_id)>   m_PurchaseCallback;
}

@synthesize onProductPurchased = m_PurchaseCallback;

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
    for( SKProduct* p in response.products ) {
        if( [p.productIdentifier isEqualToString:g_ProFeaturesInAppID] )
            m_ProFeaturesProduct = p;
        
//        NSLog(@"%@ %@ %@", p.productIdentifier, p.localizedTitle, p.price);
    }    
}

// background thread
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
}

// background thread
- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for( SKPaymentTransaction *pt in transactions ) {
        switch( pt.transactionState ) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored: {
                string identifier = pt.payment.productIdentifier.UTF8String;
                auto callback = m_PurchaseCallback;
                if( callback )
                    dispatch_to_main_queue([=]{ callback(identifier); } );                
                [queue finishTransaction:pt];
                break;
            }
            case SKPaymentTransactionStateFailed:
            case SKPaymentTransactionStateDeferred:;
                [queue finishTransaction:pt];
                break;
            default:
                break;
        }
    }
}

- (void) askUserToBuyProFeatures
{
    if( !m_ProFeaturesProduct )
        return;
    
    
    SKPayment *payment = [SKPayment paymentWithProduct:m_ProFeaturesProduct];
    [SKPaymentQueue.defaultQueue addPayment:payment];
}

- (void) askUserToRestorePurchases
{
    if( !m_ProFeaturesProduct )
        return;
    
    [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
}

//- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
//{
//    auto callback = m_PurchaseCallback;
//    for( SKPaymentTransaction *transaction in queue.transactions ) {
//        string identifier = transaction.payment.productIdentifier.UTF8String;
//        if( callback )
//            dispatch_to_main_queue([=]{ callback(identifier); } );
//    }
//}

@end
