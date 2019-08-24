// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppStoreHelper.h"
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/dispatch_cpp.h>
#include <NimbleCommander/GeneralUI/ProFeaturesWindowController.h>
#include <NimbleCommander/Core/FeedbackManager.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>

static const auto g_ProFeaturesInAppID  = @"com.magnumbytes.nimblecommander.paid_features";
static const auto g_PrefsPriceString    = @"proFeaturesIAPPriceString";
static const auto g_PrefsPFDontShow     = CFSTR("proFeaturesIAPDontShow");
static const auto g_PrefsPFNextTime     = CFSTR("proFeaturesIAPNextShowTime");

std::string CFBundleGetAppStoreReceiptPath( CFBundleRef _bundle )
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
    SKProductsRequest                  *m_ProductRequest;
    SKProduct                          *m_ProFeaturesProduct;
    std::function<void(const std::string &_id)> m_PurchaseCallback;
    NSString                           *m_PriceString;
    std::function<void()>              m_OnProFeaturesProductFetched;    
}

@synthesize onProductPurchased = m_PurchaseCallback;
@synthesize priceString = m_PriceString;
@synthesize proFeaturesProduct = m_ProFeaturesProduct;

- (id) init
{
    if(self = [super init]) {
        m_ProFeaturesProduct = nil;
        m_ProductRequest = nil;
        
        [SKPaymentQueue.defaultQueue addTransactionObserver:self];
        const auto products = [NSSet setWithObject:g_ProFeaturesInAppID];
        m_ProductRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:products];
        m_ProductRequest.delegate = self;
        [m_ProductRequest start];
        
        m_PriceString = [NSUserDefaults.standardUserDefaults objectForKey:g_PrefsPriceString];
        if( !m_PriceString )
            m_PriceString = @"";
    }
    return self;
}

// background thread
- (void)productsRequest:(SKProductsRequest *)[[maybe_unused]]request
     didReceiveResponse:(SKProductsResponse *)response
{
    for( SKProduct* p in response.products ) {
        if( [p.productIdentifier isEqualToString:g_ProFeaturesInAppID] ) {
            m_ProFeaturesProduct = p;
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
            formatter.numberStyle = NSNumberFormatterCurrencyStyle;
            formatter.locale = p.priceLocale;
            NSString *price_string = [formatter stringFromNumber:p.price];
            if( ![price_string isEqualToString:m_PriceString] ) {
                m_PriceString = price_string;
                [NSUserDefaults.standardUserDefaults setObject:m_PriceString
                                                        forKey:g_PrefsPriceString];
            }
        }
    }
    
    if( m_ProFeaturesProduct != nil ) {
        dispatch_to_main_queue([self]{
            if( m_OnProFeaturesProductFetched )
                m_OnProFeaturesProductFetched();
        });        
    }
}

// background thread
- (void)request:(SKRequest *)[[maybe_unused]]request
didFailWithError:(NSError *)[[maybe_unused]]error
{
}

// background thread
- (void) paymentQueue:(SKPaymentQueue *)queue
  updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for( SKPaymentTransaction *pt in transactions ) {
        switch( pt.transactionState ) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored: {
                std::string identifier = pt.payment.productIdentifier.UTF8String;
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
    dispatch_assert_main_queue();    
    if( m_ProFeaturesProduct != nil ) {
        [self doAskUserToBuyProFeatures];
    }
    else {
        const auto timeout = time(nullptr) + 60;
        m_OnProFeaturesProductFetched = [self, timeout]{
            if( time(nullptr) < timeout )
                [self doAskUserToBuyProFeatures];
        };
    }
}

- (void)doAskUserToBuyProFeatures
{
    assert( m_ProFeaturesProduct != nil );
    dispatch_assert_main_queue();
    GA().PostEvent("Licensing", "Buy", "Buy Pro features IAP");
    SKPayment *payment = [SKPayment paymentWithProduct:m_ProFeaturesProduct];
    [SKPaymentQueue.defaultQueue addPayment:payment];
}

- (void) askUserToRestorePurchases
{
    if( !m_ProFeaturesProduct )
        return;
    
    GA().PostEvent("Licensing", "Buy", "Restore IAP purchases");
    [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
}

- (void) showProFeaturesWindow
{
    dispatch_assert_main_queue();
    ProFeaturesWindowController *w = [[ProFeaturesWindowController alloc] init];
    w.suppressDontShowAgain = true;
    GA().PostEvent("Licensing", "Buy", "Show Pro features IAP");
    
    const auto result = [NSApp runModalForWindow:w.window];
    
    if( result == NSModalResponseOK )
        [self askUserToBuyProFeatures];
}

- (void) showProFeaturesWindowIfNeededAsNagScreen
{
    dispatch_assert_main_queue();
    const auto min_runs = 10;
    const auto next_show_delay = 60l * 60l* 24l * 14l; // every 14 days

    if( nc::bootstrap::ActivationManager::Instance().UsedHadPurchasedProFeatures() ||      // don't show nag screen if user has already bought pro features
        FeedbackManager::Instance().ApplicationRunsCount() < min_runs ||    // don't show nag screen if user didn't use software for long enough
        CFDefaultsGetBool(g_PrefsPFDontShow) )                              // don't show nag screen it user has opted to
        return;
    
    const auto next_time = CFDefaultsGetOptionalLong(g_PrefsPFNextTime);
    if( next_time && *next_time > time(0) )
        return; // it's not time yet
    
    // setup next show time
    CFDefaultsSetLong(g_PrefsPFNextTime, time(0) + next_show_delay);
    
    // let's show a nag screen
    GA().PostEvent("Licensing", "Buy", "Show Pro features IAP As Nagscreen");

    ProFeaturesWindowController *w = [[ProFeaturesWindowController alloc] init];
    w.priceText = self.priceString;
    const auto result = [NSApp runModalForWindow:w.window];
    
    if( w.dontShowAgain ) {
        CFDefaultsSetBool(g_PrefsPFDontShow, true);
        GA().PostEvent("Licensing", "Buy", "User has turned off IAP Nagscreen");
    }
    if( result == NSModalResponseOK ) {
        dispatch_to_main_queue([self] {
            [self askUserToBuyProFeatures];
        });
    }
}

@end
