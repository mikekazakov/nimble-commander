// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <unordered_map>

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
    virtual const std::unordered_map<std::string, std::string> &
    LicenseInformation() const noexcept = 0;

    // Free MAS version stuff
    virtual bool ReCheckProFeaturesInAppPurchased() = 0; // will recheck receipt file and return
                                                         // true if in-app was purchased
    virtual bool UsedHadPurchasedProFeatures() const noexcept = 0;
};

} // namespace nc::bootstrap
