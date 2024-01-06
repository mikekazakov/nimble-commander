// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <string>

namespace nc {
class FeedbackManager;
}

namespace nc::bootstrap {

class ActivationManager;

}

#ifdef __OBJC__

#include <StoreKit/StoreKit.h>

@interface AppStoreHelper : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am
                          feedbackManager:(nc::FeedbackManager &)_fm;

@property(nonatomic) std::function<void(const std::string &_id)> onProductPurchased;
@property(nonatomic, readonly) NSString *priceString;
@property(nonatomic, readonly) SKProduct *proFeaturesProduct;

- (void)askUserToRestorePurchases;

- (void)showProFeaturesWindow;
- (void)showProFeaturesWindowIfNeededAsNagScreen;

@end

#endif
