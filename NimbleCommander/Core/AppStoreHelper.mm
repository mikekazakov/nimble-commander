// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppStoreHelper.h"
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/dispatch_cpp.h>
#include <NimbleCommander/GeneralUI/ProFeaturesWindowController.h>
#include <NimbleCommander/Core/FeedbackManager.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>

static const auto g_ProFeaturesInAppID = @"com.magnumbytes.nimblecommander.paid_features";
static const auto g_PrefsPriceString = @"proFeaturesIAPPriceString";
static const auto g_PrefsPFDontShow = CFSTR("proFeaturesIAPDontShow");
static const auto g_PrefsPFNextTime = CFSTR("proFeaturesIAPNextShowTime");

@implementation AppStoreHelper {
    SKProductsRequest *m_ProductRequest;
    SKProduct *m_ProFeaturesProduct;
    std::function<void(const std::string &_id)> m_PurchaseCallback;
    NSString *m_PriceString;
    std::function<void()> m_OnProFeaturesProductFetched;
    nc::bootstrap::ActivationManager *m_ActivationManager;
    nc::FeedbackManager *m_FeedbackManager;
}

@synthesize onProductPurchased = m_PurchaseCallback;
@synthesize priceString = m_PriceString;
@synthesize proFeaturesProduct = m_ProFeaturesProduct;

- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am
                          feedbackManager:(nc::FeedbackManager &)_fm
{
    if( self = [super init] ) {
        m_ActivationManager = &_am;
        m_FeedbackManager = &_fm;
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
- (void)productsRequest:(SKProductsRequest *) [[maybe_unused]] request didReceiveResponse:(SKProductsResponse *)response
{
    for( SKProduct *p in response.products ) {
        if( [p.productIdentifier isEqualToString:g_ProFeaturesInAppID] ) {
            m_ProFeaturesProduct = p;

            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
            formatter.numberStyle = NSNumberFormatterCurrencyStyle;
            formatter.locale = p.priceLocale;
            NSString *price_string = [formatter stringFromNumber:p.price];
            if( ![price_string isEqualToString:m_PriceString] ) {
                m_PriceString = price_string;
                [NSUserDefaults.standardUserDefaults setObject:m_PriceString forKey:g_PrefsPriceString];
            }
        }
    }

    if( m_ProFeaturesProduct != nil ) {
        dispatch_to_main_queue([self] {
            if( m_OnProFeaturesProductFetched )
                m_OnProFeaturesProductFetched();
        });
    }
}

// background thread
- (void)request:(SKRequest *) [[maybe_unused]] request didFailWithError:(NSError *) [[maybe_unused]] error
{
}

// background thread
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for( SKPaymentTransaction *pt in transactions ) {
        switch( pt.transactionState ) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored: {
                std::string identifier = pt.payment.productIdentifier.UTF8String;
                auto callback = m_PurchaseCallback;
                if( callback )
                    dispatch_to_main_queue([=] { callback(identifier); });
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

- (void)askUserToBuyProFeatures
{
    dispatch_assert_main_queue();
    if( m_ProFeaturesProduct != nil ) {
        [self doAskUserToBuyProFeatures];
    }
    else {
        const auto timeout = time(nullptr) + 60;
        m_OnProFeaturesProductFetched = [self, timeout] {
            if( time(nullptr) < timeout )
                [self doAskUserToBuyProFeatures];
        };
    }
}

- (void)doAskUserToBuyProFeatures
{
    assert(m_ProFeaturesProduct != nil);
    dispatch_assert_main_queue();
    SKPayment *payment = [SKPayment paymentWithProduct:m_ProFeaturesProduct];
    [SKPaymentQueue.defaultQueue addPayment:payment];
}

- (void)askUserToRestorePurchases
{
    if( !m_ProFeaturesProduct )
        return;

    [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
}

- (void)showProFeaturesWindow
{
    dispatch_assert_main_queue();
    ProFeaturesWindowController *w = [[ProFeaturesWindowController alloc] init];
    w.suppressDontShowAgain = true;
    const auto result = [NSApp runModalForWindow:w.window];

    if( result == NSModalResponseOK )
        [self askUserToBuyProFeatures];
}

- (void)showProFeaturesWindowIfNeededAsNagScreen
{
    dispatch_assert_main_queue();
    const auto min_runs = 10;
    const auto next_show_delay = 60l * 60l * 24l * 14l; // every 14 days

    if( m_ActivationManager->UsedHadPurchasedProFeatures() || // don't show nag screen if user has
                                                              // already bought pro features
        m_FeedbackManager->ApplicationRunsCount() <
            min_runs || // don't show nag screen if user didn't use software for long enough
        nc::base::CFDefaultsGetBool(g_PrefsPFDontShow) ) // don't show nag screen it user has opted to
        return;

    const auto next_time = nc::base::CFDefaultsGetOptionalLong(g_PrefsPFNextTime);
    if( next_time && *next_time > time(0) )
        return; // it's not time yet

    // setup next show time
    nc::base::CFDefaultsSetLong(g_PrefsPFNextTime, time(0) + next_show_delay);

    // let's show a nag screen
    ProFeaturesWindowController *w = [[ProFeaturesWindowController alloc] init];
    w.priceText = self.priceString;
    const auto result = [NSApp runModalForWindow:w.window];

    if( w.dontShowAgain ) {
        nc::base::CFDefaultsSetBool(g_PrefsPFDontShow, true);
    }
    if( result == NSModalResponseOK ) {
        dispatch_to_main_queue([self] { [self askUserToBuyProFeatures]; });
    }
}

@end
