// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__

#include <StoreKit/StoreKit.h>
#include <functional>
#include <string>

@interface AppStoreHelper : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic) std::function<void(const std::string &_id)> onProductPurchased;
@property (nonatomic, readonly) NSString *priceString;
@property (nonatomic, readonly) SKProduct *proFeaturesProduct;

- (void) askUserToRestorePurchases;

- (void) showProFeaturesWindow;
- (void) showProFeaturesWindowIfNeededAsNagScreen;

@end

#endif

std::string CFBundleGetAppStoreReceiptPath( CFBundleRef _bundle );
