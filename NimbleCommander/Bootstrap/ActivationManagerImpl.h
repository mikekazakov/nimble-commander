// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ActivationManager.h"
#include "ActivationManagerBase.h"

class GoogleAnalytics;

namespace nc::bootstrap {

class ActivationManagerImpl : public ActivationManager
{
public:
    ActivationManagerImpl(ActivationManagerBase::ExternalLicenseSupport &_ext_license_support,
                          ActivationManagerBase::TrialPeriodSupport &_trial_period_support,
                          GoogleAnalytics &_ga);
    ActivationManagerImpl(const ActivationManagerImpl &) = delete;
    static ActivationManagerImpl &Instance();
    Distribution Type() const noexcept override;
    bool Sandboxed() const noexcept override;
    bool ForAppStore() const noexcept override;
    const std::string &AppStoreID() const noexcept override;
    bool HasPSFS() const noexcept override;
    bool HasXAttrFS() const noexcept override;
    bool HasTerminal() const noexcept override;
    bool HasExternalTools() const noexcept override;
    bool HasBriefSystemOverview() const noexcept override;
    bool HasUnixAttributesEditing() const noexcept override;
    bool HasDetailedVolumeInformation() const noexcept override;
    bool HasInternalViewer() const noexcept override;
    bool HasCompressionOperation() const noexcept override;
    bool HasArchivesBrowsing() const noexcept override;
    bool HasLinksManipulation() const noexcept override;
    bool HasNetworkConnectivity() const noexcept override;
    bool HasLANSharesMounting() const noexcept override;
    bool HasChecksumCalculation() const noexcept override;
    bool HasBatchRename() const noexcept override;
    bool HasCopyVerification() const noexcept override;
    bool HasRoutedIO() const noexcept override;
    bool HasTemporaryPanels() const noexcept override;
    bool HasSpotlightSearch() const noexcept override;
    bool HasThemesManipulation() const noexcept override;

    // Trial NonMAS version stuff
    bool UserHadRegistered() const noexcept override;
    bool UserHasProVersionInstalled() const noexcept override;
    bool IsTrialPeriod() const noexcept override;
    int TrialDaysLeft() const noexcept override;
    bool ShouldShowTrialNagScreen() const noexcept override;
    const std::string &LicenseFileExtension() const noexcept override;
    bool ProcessLicenseFile(const std::string &_path) override;
    const std::unordered_map<std::string, std::string> &
    LicenseInformation() const noexcept override;

    // Free MAS version stuff
    bool ReCheckProFeaturesInAppPurchased() override;
    bool UsedHadPurchasedProFeatures() const noexcept override;

private:
#if defined(__NC_VERSION_FREE__)
    static const Distribution m_Type = Distribution::Free;
    static const bool m_IsSandBoxed = true;
    const std::string m_AppStoreIdentifier = "905202937";
#elif defined(__NC_VERSION_PAID__)
    static const Distribution m_Type = Distribution::Paid;
    static const bool m_IsSandBoxed = true;
    const std::string m_AppStoreIdentifier = "942443942";
#elif defined(__NC_VERSION_TRIAL__)
    static const Distribution m_Type = Distribution::Trial;
    static const bool m_IsSandBoxed = false;
    const std::string m_AppStoreIdentifier = "";
#else
#error Invalid build configuration - no version type specified
#endif

    bool m_IsActivated = false;
    bool m_UserHadRegistered = false;
    int m_TrialDaysLeft = 0;
    bool m_IsTrialPeriod = false;
    bool m_UserHasProVersionInstalled = false;
    std::unordered_map<std::string, std::string> m_LicenseInfo;
    ActivationManagerBase::ExternalLicenseSupport &m_ExtLicenseSupport;
    ActivationManagerBase::TrialPeriodSupport &m_TrialPeriodSupport;
    GoogleAnalytics &m_GA;
};

} // namespace nc::bootstrap
