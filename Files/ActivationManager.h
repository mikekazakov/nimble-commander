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
    constexpr Distribution  Type()          const { return m_Type; }
    constexpr bool          Sandboxed()     const { return m_IsSandBoxed; }
    constexpr bool          ForAppStore()   const { return Sandboxed(); }
    const string&           BundleID() const;
    const string&           AppStoreID() const;
    bool HasPSFS() const noexcept;
    bool HasXAttrFS() const noexcept;
    bool HasTerminal() const noexcept;
    bool HasBriefSystemOverview() const noexcept;
    bool HasUnixAttributesEditing() const noexcept;
    bool HasDetailedVolumeInformation() const noexcept;
    bool HasInternalViewer() const noexcept;
    bool HasCompressionOperation() const noexcept;
    bool HasArchivesBrowsing() const noexcept;
    bool HasLinksManipulation() const noexcept;
    bool HasNetworkConnectivity() const noexcept;
    bool HasChecksumCalculation() const noexcept;
    bool HasBatchRename() const noexcept;
    bool HasCopyVerification() const noexcept;
    bool HasRoutedIO() const noexcept;
    bool HasTemporaryPanels() const noexcept;
    
private:
    ActivationManager();
  
#if   defined(__NC_VERSION_FREE__)
    static const Distribution m_Type = Distribution::Free;
    static const bool m_IsSandBoxed = true;
    const string m_BundleID = "info.filesmanager.Files-Lite"s;
    const string m_AppStoreIdentifier = "905202937"s;
#elif defined(__NC_VERSION_PAID__)
    static const Distribution m_Type = Distribution::Paid;
    static const bool m_IsSandBoxed = true;
    const string m_BundleID = "info.filesmanager.Files-Pro"s;
    const string m_AppStoreIdentifier = "942443942"s;
#elif defined(__NC_VERSION_TRIAL__)
    static const Distribution m_Type = Distribution::Trial;
    static const bool m_IsSandBoxed = false;
    const string m_BundleID = "info.filesmanager.Files"s;
    const string m_AppStoreIdentifier = ""s;
#else
    #error Invalid build configuration - no version type specified
#endif

    bool m_IsActivated = false;
};
