// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ActivationManagerBase.h"

class GoogleAnalytics;

namespace nc::bootstrap {

class ActivationManager
{
public:
    enum class Distribution
    {
        /**
         * Sandboxed version with reduced functionality initially.
         * Presumably free on MacAppStore, with an in-app purchase.
         */
        Free,

        /**
         * Sandboxed version with as maximum functionality, as sandboxing model permits.
         * Presumably exists as paid version on MacAppStore.
         */
        Paid,

        /**
         * Non-sandboxed version with whole functionality available as a trial.
         */
        Trial
    };
    
    virtual ~ActivationManager() = default;

    // Queries
    virtual Distribution Type() const noexcept = 0;
    virtual bool Sandboxed() const noexcept = 0;
    virtual bool ForAppStore() const noexcept = 0;
    virtual const std::string &AppStoreID() const noexcept = 0;
    virtual bool HasPSFS() const noexcept = 0;
    virtual bool HasXAttrFS() const noexcept = 0;
    virtual bool HasTerminal() const noexcept = 0;
    virtual bool HasExternalTools() const noexcept = 0;
    virtual bool HasBriefSystemOverview() const noexcept = 0;
    virtual bool HasUnixAttributesEditing() const noexcept = 0;
    virtual bool HasDetailedVolumeInformation() const noexcept = 0;
    virtual bool HasInternalViewer() const noexcept = 0;
    virtual bool HasCompressionOperation() const noexcept = 0;
    virtual bool HasArchivesBrowsing() const noexcept = 0;
    virtual bool HasLinksManipulation() const noexcept = 0;
    virtual bool HasNetworkConnectivity() const noexcept = 0;
    virtual bool HasLANSharesMounting() const noexcept = 0;
    virtual bool HasChecksumCalculation() const noexcept = 0;
    virtual bool HasBatchRename() const noexcept = 0;
    virtual bool HasCopyVerification() const noexcept = 0;
    virtual bool HasRoutedIO() const noexcept = 0;
    virtual bool HasTemporaryPanels() const noexcept = 0;
    virtual bool HasSpotlightSearch() const noexcept = 0;
    virtual bool HasThemesManipulation() const noexcept = 0;

    // Trial NonMAS version stuff
    virtual bool UserHadRegistered() const noexcept = 0;
    virtual bool UserHasProVersionInstalled() const noexcept = 0;
    virtual bool IsTrialPeriod() const noexcept = 0;
    virtual int TrialDaysLeft() const noexcept = 0; // zero means that trial has expired
    virtual bool ShouldShowTrialNagScreen() const noexcept = 0;
    virtual const std::string &LicenseFileExtension() const noexcept = 0;
    virtual bool ProcessLicenseFile(const std::string &_path) = 0;
    virtual const std::unordered_map<std::string, std::string> &LicenseInformation() const noexcept = 0;

    // Free MAS version stuff
    virtual bool ReCheckProFeaturesInAppPurchased() = 0; // will recheck receipt file and return true if in-app was purchased
    virtual bool UsedHadPurchasedProFeatures() const noexcept = 0;
};

class ActivationManagerImpl : public ActivationManager
{
public:
    ActivationManagerImpl(ActivationManagerBase::ExternalLicenseSupport &_ext_license_support,
                      ActivationManagerBase::TrialPeriodSupport &_trial_period_support,
                      GoogleAnalytics &_ga);
    ActivationManagerImpl(const ActivationManagerImpl&)=delete;
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
    const std::unordered_map<std::string, std::string> &LicenseInformation() const noexcept  override;

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
