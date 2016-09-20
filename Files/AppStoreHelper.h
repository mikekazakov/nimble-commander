#pragma once

#ifdef __OBJC__

#include <StoreKit/StoreKit.h>

@interface AppStoreHelper : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic) function<void(const string &_id)> onProductPurchased;
@property (nonatomic, readonly) NSString *priceString;

- (void) askUserToBuyProFeatures;
- (void) askUserToRestorePurchases;

- (void) showProFeaturesWindow;
- (void) showProFeaturesWindowIfNeededAsNagScreen;

@end

#endif

string CFBundleGetAppStoreReceiptPath( CFBundleRef _bundle );
