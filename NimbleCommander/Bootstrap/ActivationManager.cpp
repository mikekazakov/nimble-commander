// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SystemInformation.h>
#include <VFS/Native.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Marketing/MASAppInstalledChecker.h>
#include <NimbleCommander/Core/AppStoreHelper.h>
#include <NimbleCommander/Bootstrap/NCE.h>
#include "AppDelegateCPP.h"
#include "ActivationManager.h"

namespace nc::bootstrap {

using namespace std::literals;
    
// trial non-mas version setup
static const auto g_LicenseExtension = "nimblecommanderlicense"s;
static const auto g_LicenseFilename = "registration."s + g_LicenseExtension;
static CFStringRef const g_DefaultsTrialExpireDate = CFSTR("TrialExpirationDate");
static const int g_TrialPeriodDays = 30;
static const int g_TrialNagScreenMinDays = 15; // when amount of trial days becomes less that this value - an app will start showing a nag screen upon startup
static const double g_TrialPeriodTimeInterval = 60.*60.*24.*g_TrialPeriodDays; // 30 days

// free mas version setup
static const auto g_ProFeaturesInAppID = "com.magnumbytes.nimblecommander.paid_features"s;
static std::optional<std::string> Load(const std::string &_filepath);
    
static bool UserHasPaidVersionInstalled()
{
    return MASAppInstalledChecker::Instance().Has("Files Pro.app",            "info.filesmanager.Files-Pro") ||
           MASAppInstalledChecker::Instance().Has("Nimble Commander Pro.app", "info.filesmanager.Files-Pro");
}

static bool AppStoreReceiptContainsProFeaturesInApp()
{
    std::string receipt_path = CFBundleGetAppStoreReceiptPath( CFBundleGetMainBundle() );
    
    VFSFilePtr source;
    if( VFSNativeHost::SharedHost()->CreateFile(receipt_path.c_str(), source, nullptr) != VFSError::Ok )
        return false;
    
    if( source->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock) != VFSError::Ok )
        return false;
    
    auto data = source->ReadFile();
    if( !data )
        return false;
    
    source->Close();
    
    return memmem( data->data(), data->size(), g_ProFeaturesInAppID.data(), g_ProFeaturesInAppID.length() ) != 0;
}

static std::string InstalledAquaticLicensePath()
{
    return nc::AppDelegate::SupportDirectory() + g_LicenseFilename;
}

static std::string AquaticPrimePublicKey()
{
    std::string key;
    key += NCE(nc::env::aqp_pk_00);
    key += NCE(nc::env::aqp_pk_01);
    key += NCE(nc::env::aqp_pk_02);
    key += NCE(nc::env::aqp_pk_03);
    key += NCE(nc::env::aqp_pk_04);
    key += NCE(nc::env::aqp_pk_05);
    key += NCE(nc::env::aqp_pk_06);
    key += NCE(nc::env::aqp_pk_07);
    key += NCE(nc::env::aqp_pk_08);
    key += NCE(nc::env::aqp_pk_09);
    key += NCE(nc::env::aqp_pk_10);
    key += NCE(nc::env::aqp_pk_11);
    key += NCE(nc::env::aqp_pk_12);
    key += NCE(nc::env::aqp_pk_13);
    key += NCE(nc::env::aqp_pk_14);
    key += NCE(nc::env::aqp_pk_15);
    key += NCE(nc::env::aqp_pk_16);
    key += NCE(nc::env::aqp_pk_17);
    key += NCE(nc::env::aqp_pk_18);
    key += NCE(nc::env::aqp_pk_19);
    key += NCE(nc::env::aqp_pk_20);
    key += NCE(nc::env::aqp_pk_21);
    key += NCE(nc::env::aqp_pk_22);
    key += NCE(nc::env::aqp_pk_23);
    key += NCE(nc::env::aqp_pk_24);
    key += NCE(nc::env::aqp_pk_25);
    key += NCE(nc::env::aqp_pk_26);
    key += NCE(nc::env::aqp_pk_27);
    key += NCE(nc::env::aqp_pk_28);
    key += NCE(nc::env::aqp_pk_29);
    key += NCE(nc::env::aqp_pk_30);
    key += NCE(nc::env::aqp_pk_31);
    key += NCE(nc::env::aqp_pk_32);
    return key;
}
    
ActivationManager &ActivationManager::Instance()
{
    static auto ext_license_support =
        ActivationManagerBase::ExternalLicenseSupport{ AquaticPrimePublicKey(),
                InstalledAquaticLicensePath() };
    static auto trial_period_support = 
        ActivationManagerBase::TrialPeriodSupport{ g_DefaultsTrialExpireDate };
    static auto inst = ActivationManager{ ext_license_support, trial_period_support, GA() };
    return inst;
}

ActivationManager::ActivationManager
    ( ActivationManagerBase::ExternalLicenseSupport &_ext_license_support,
     ActivationManagerBase::TrialPeriodSupport &_trial_period_support,
      GoogleAnalytics &_ga):
    m_ExtLicenseSupport(_ext_license_support),
    m_TrialPeriodSupport(_trial_period_support),
    m_GA(_ga)
{
    if( m_Type == Distribution::Paid ) {
        m_IsActivated = true;
    }
    else if( m_Type == Distribution::Trial ) {
        const bool has_mas_paid_version = UserHasPaidVersionInstalled();
        if(has_mas_paid_version)
            m_GA.PostEvent("Licensing", "Activated Startup", "MAS Installed");
        const bool has_valid_license = m_ExtLicenseSupport.HasValidInstalledLicense();
        if( has_valid_license ) {
            m_LicenseInfo = m_ExtLicenseSupport.ExtractInfoFromInstalledLicense();            
            m_GA.PostEvent("Licensing", "Activated Startup", "License Installed");
        }
        
        m_UserHadRegistered = has_mas_paid_version || has_valid_license;
        m_UserHasProVersionInstalled = has_mas_paid_version;
        m_IsActivated = true /*has_mas_paid_version || has_valid_license*/;
        
        if( !m_UserHadRegistered ) {
            if( m_TrialPeriodSupport.IsTrialStarted() == false )
                m_TrialPeriodSupport.SetupTrialPeriod( g_TrialPeriodTimeInterval );

            m_TrialDaysLeft = m_TrialPeriodSupport.TrialDaysLeft();
            
            if( m_TrialDaysLeft > 0 ) {
                m_IsTrialPeriod = true;
                m_GA.PostEvent("Licensing", "Trial Startup", "Trial valid", m_TrialDaysLeft);
            }
            else {
                m_IsTrialPeriod = false;
                m_GA.PostEvent("Licensing", "Trial Startup", "Trial exceeded", 0);
            }
        }
    }
    else { // m_Type == Distribution::Free
        m_IsActivated = AppStoreReceiptContainsProFeaturesInApp();
    }
}

const std::string& ActivationManager::BundleID()
{
    return nc::utility::GetBundleID();
}

const std::string& ActivationManager::AppStoreID() const
{
    return m_AppStoreIdentifier;
}

bool ActivationManager::HasPSFS() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasXAttrFS() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasTerminal() const noexcept
{
    return !Sandboxed() && m_IsActivated;
}

bool ActivationManager::HasRoutedIO() const noexcept
{
    return !Sandboxed() && m_IsActivated;
}

bool ActivationManager::HasBriefSystemOverview() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasExternalTools() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasUnixAttributesEditing() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasDetailedVolumeInformation() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasInternalViewer() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasCompressionOperation() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasArchivesBrowsing() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasLinksManipulation() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasNetworkConnectivity() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasLANSharesMounting() const noexcept
{
    return !m_IsSandBoxed && m_IsActivated;
}

bool ActivationManager::HasChecksumCalculation() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasBatchRename() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasCopyVerification() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasTemporaryPanels() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasSpotlightSearch() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::HasThemesManipulation() const noexcept
{
    return m_IsActivated;
}

bool ActivationManager::IsTrialPeriod() const noexcept
{
    return m_IsTrialPeriod;
}

int ActivationManager::TrialDaysLeft() const noexcept
{
    return m_TrialDaysLeft;
}

const std::string &ActivationManager::LicenseFileExtension() noexcept
{
    return g_LicenseExtension;
}

bool ActivationManager::ProcessLicenseFile( const std::string& _path )
{
    if( Type() != ActivationManager::Distribution::Trial )
        return false;
        
    const auto license_data = Load(_path);
    if( license_data == std::nullopt )
        return false;

    if( m_ExtLicenseSupport.CheckLicenseValidity(*license_data) == false )
        return false;
    
    if( m_ExtLicenseSupport.InstallNewLicenseWithData(*license_data) == false )
        return false;
    
    const auto valid = m_ExtLicenseSupport.HasValidInstalledLicense();
    if( valid ) {
        m_UserHadRegistered = true; 
        m_LicenseInfo = m_ExtLicenseSupport.ExtractInfoFromInstalledLicense();
    }
    
    return m_UserHadRegistered;
}

bool ActivationManager::UserHadRegistered() const noexcept
{
    return m_UserHadRegistered;
}

bool ActivationManager::ShouldShowTrialNagScreen() const noexcept
{
    return Type() == ActivationManager::Distribution::Trial &&
            !m_UserHadRegistered &&
            TrialDaysLeft() <= g_TrialNagScreenMinDays ;
}

bool ActivationManager::ReCheckProFeaturesInAppPurchased()
{
    if( Type() != ActivationManager::Distribution::Free )
        return false;
    m_IsActivated = AppStoreReceiptContainsProFeaturesInApp();
    return m_IsActivated;
}

bool ActivationManager::UsedHadPurchasedProFeatures() const noexcept
{
    return Type() == Distribution::Free &&
           m_IsActivated == true;
}

const std::unordered_map<std::string, std::string> &
    ActivationManager::LicenseInformation() const noexcept
{
    return m_LicenseInfo;
}

bool ActivationManager::UserHasProVersionInstalled() const noexcept
{
    return m_UserHasProVersionInstalled;
}

static std::optional<std::string> Load(const std::string &_filepath)
{
    std::ifstream in( _filepath, std::ios::in | std::ios::binary );
    if( !in )
        return std::nullopt;        
    
    std::string contents;
    in.seekg( 0, std::ios::end );
    contents.resize( in.tellg() );
    in.seekg( 0, std::ios::beg );
    in.read( &contents[0], contents.size() );
    in.close();
    return contents;
}

}
