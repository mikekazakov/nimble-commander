// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

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

    static ActivationManager &Instance();
    static constexpr Distribution   Type()          { return m_Type; }
    static constexpr bool           Sandboxed()     { return m_IsSandBoxed; }
    static constexpr bool           ForAppStore()   { return Sandboxed(); }
    static const string&           BundleID();
    const string&           AppStoreID() const;
    bool HasPSFS() const noexcept;
    bool HasXAttrFS() const noexcept;
    bool HasTerminal() const noexcept;
    bool HasExternalTools() const noexcept;
    bool HasBriefSystemOverview() const noexcept;
    bool HasUnixAttributesEditing() const noexcept;
    bool HasDetailedVolumeInformation() const noexcept;
    bool HasInternalViewer() const noexcept;
    bool HasCompressionOperation() const noexcept;
    bool HasArchivesBrowsing() const noexcept;
    bool HasLinksManipulation() const noexcept;
    bool HasNetworkConnectivity() const noexcept;
    bool HasLANSharesMounting() const noexcept;
    bool HasChecksumCalculation() const noexcept;
    bool HasBatchRename() const noexcept;
    bool HasCopyVerification() const noexcept;
    bool HasRoutedIO() const noexcept;
    bool HasTemporaryPanels() const noexcept;
    bool HasSpotlightSearch() const noexcept;
    bool HasThemesManipulation() const noexcept;
    
    // Trial NonMAS version stuff
    bool UserHadRegistered() const noexcept;
    bool UserHasProVersionInstalled() const noexcept;
    bool IsTrialPeriod() const noexcept;
    int TrialDaysLeft() const noexcept; // zero means that trial has expired
    bool ShouldShowTrialNagScreen() const noexcept;
    static const string &LicenseFileExtension() noexcept; // currently it's "nimblecommanderlicence"
    bool ProcessLicenseFile(const string& _path );
    const unordered_map<string, string> &LicenseInformation() const noexcept;
    
    // Free MAS version stuff
    bool ReCheckProFeaturesInAppPurchased(); // will recheck receipt file and return true if in-app was purchased
    bool UsedHadPurchasedProFeatures() const noexcept;
    
private:
    ActivationManager();
  
#if   defined(__NC_VERSION_FREE__)
    static const Distribution m_Type = Distribution::Free;
    static const bool m_IsSandBoxed = true;
    const string m_AppStoreIdentifier = "905202937"s;
#elif defined(__NC_VERSION_PAID__)
    static const Distribution m_Type = Distribution::Paid;
    static const bool m_IsSandBoxed = true;
    const string m_AppStoreIdentifier = "942443942"s;
#elif defined(__NC_VERSION_TRIAL__)
    static const Distribution m_Type = Distribution::Trial;
    static const bool m_IsSandBoxed = false;
    const string m_AppStoreIdentifier = ""s;
#else
    #error Invalid build configuration - no version type specified
#endif

    bool    m_IsActivated = false;
    bool    m_UserHadRegistered = false;
    int     m_TrialDaysLeft = 0;
    bool    m_IsTrialPeriod = false;
    bool    m_UserHasProVersionInstalled = false;
    unordered_map<string, string> m_LicenseInfo;
};
