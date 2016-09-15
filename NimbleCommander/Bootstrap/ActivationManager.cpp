#include <AquaticPrime/AquaticPrime.h>
#include <Habanero/CFDefaultsCPP.h>
#include <copyfile.h>
#include "../../Files/vfs/VFS.h"
#include "../../Files/vfs/vfs_native.h"
#include "../../Files/MASAppInstalledChecker.h"
#include "../../Files/AppDelegateCPP.h"
#include "../../Files/GoogleAnalytics.h"
#include "../../Files/AppStoreHelper.h"
#include "ActivationManager.h"

// trial non-mas version setup
static const auto g_LicenseExtension = "nimblecommanderlicense"s;
static const auto g_LicenseFilename = "registration."s + g_LicenseExtension;
static CFStringRef const g_DefaultsTrialExpireDate = CFSTR("TrialExpirationDate");
static const int g_TrialPeriodDays = 30;
static const int g_TrialNagScreenMinDays = 15; // when amount of trial days becomes less that this value - an app will start showing a nag screen upon startup
static const double g_TrialPeriodTimeInterval = 60.*60.*24.*g_TrialPeriodDays; // 30 days

// free mas version setup
static const auto g_ProFeaturesInAppID = "com.magnumbytes.nimblecommander.paid_features"s;

static bool UserHasPaidVersionInstalled()
{
    return MASAppInstalledChecker::Instance().Has("Files Pro.app",            "info.filesmanager.Files-Pro") ||
           MASAppInstalledChecker::Instance().Has("Nimble Commander Pro.app", "info.filesmanager.Files-Pro");
}

static bool AppStoreReceiptContainsProFeaturesInApp()
{
    string receipt_path = CFBundleGetAppStoreReceiptPath( CFBundleGetMainBundle() );
    
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

static bool CheckAquaticLicense( const string& _path )
{
    bool result = false;
    
    // *** Begin Public Key ***
    CFMutableStringRef key = CFStringCreateMutable(NULL, 0);
    CFStringAppend(key, CFSTR("0x"));
    CFStringAppend(key, CFSTR("D"));
    CFStringAppend(key, CFSTR("D"));
    CFStringAppend(key, CFSTR("C6D9CE4C4EA6980BAFA46CCF3D"));
    CFStringAppend(key, CFSTR("3746B1"));
    CFStringAppend(key, CFSTR("5"));
    CFStringAppend(key, CFSTR("5"));
    CFStringAppend(key, CFSTR("02156543495FFAFB6B48BC"));
    CFStringAppend(key, CFSTR("3CA349"));
    CFStringAppend(key, CFSTR("4"));
    CFStringAppend(key, CFSTR("4"));
    CFStringAppend(key, CFSTR("D3BFE421FD4DCF4E11111F"));
    CFStringAppend(key, CFSTR("E7E18386"));
    CFStringAppend(key, CFSTR("F"));
    CFStringAppend(key, CFSTR("F"));
    CFStringAppend(key, CFSTR("1B13E87A81EC4BE5559A"));
    CFStringAppend(key, CFSTR("C898"));
    CFStringAppend(key, CFSTR("B"));
    CFStringAppend(key, CFSTR("B"));
    CFStringAppend(key, CFSTR("C05AA00D5234A228EDEFBFA7"));
    CFStringAppend(key, CFSTR("3B561CA5"));
    CFStringAppend(key, CFSTR("D"));
    CFStringAppend(key, CFSTR("D"));
    CFStringAppend(key, CFSTR("52AFB6CC25099F90686B"));
    CFStringAppend(key, CFSTR("F2FE94F08350"));
    CFStringAppend(key, CFSTR("1"));
    CFStringAppend(key, CFSTR("1"));
    CFStringAppend(key, CFSTR("EA3D09EB10D0E661"));
    CFStringAppend(key, CFSTR("4"));
    CFStringAppend(key, CFSTR("8"));
    CFStringAppend(key, CFSTR("8"));
    CFStringAppend(key, CFSTR("A02025D7CEFD7471B08035C92D0"));
    CFStringAppend(key, CFSTR("8287E0D6F6E05C29BD"));
    // *** End Public Key ***
    
    APSetKey(key);
    
    if( CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8*)_path.c_str(), _path.length(), false) ) {
        if( APVerifyLicenseFile(url) )
            result = true;
        CFRelease(url);
    }
    
	CFRelease(key);
    
    return result;
}

static unordered_map<string, string> GetAquaticLicenseInfo( const string& _path )
{
    unordered_map<string, string> result;
    if( CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8*)_path.c_str(), _path.length(), false) ) {
        if( CFDictionaryRef d = APCreateDictionaryForLicenseFile(url) ) {
            CFDictionaryApplyFunction(d,
                                      [](const void *_key, const void *_value, void *_context){
                                          if( CFGetTypeID(_key) == CFStringGetTypeID() && CFGetTypeID(_value) == CFStringGetTypeID() )
                                              ((unordered_map<string, string>*)_context)->insert_or_assign( CFStringGetUTF8StdString( (CFStringRef) _key),
                                                                                                            CFStringGetUTF8StdString( (CFStringRef) _value) );
                                      },
                                      &result);
            CFRelease(d);
        }
        CFRelease(url);
    }
    
    return result;
}

static string InstalledAquaticLicensePath()
{
    return AppDelegateCPP::SupportDirectory() + g_LicenseFilename;
}

static bool UserHasValidAquaticLicense()
{
    return CheckAquaticLicense( InstalledAquaticLicensePath() );
}

static bool TrialStarted()
{
    static const double y2016 = 60.*60.*24.*365.*15.;
    return CFDefaultsGetDouble(g_DefaultsTrialExpireDate) > y2016;
}

static void SetupTrialPeriod()
{
    CFDefaultsSetDouble( g_DefaultsTrialExpireDate, CFAbsoluteTimeGetCurrent() + g_TrialPeriodTimeInterval );
}

static void DeleteTrialPeriodInfo()
{
    CFDefaultsRemoveValue( g_DefaultsTrialExpireDate );
}

static int TrialDaysLeft()
{
    double v = CFDefaultsGetDouble(g_DefaultsTrialExpireDate) - CFAbsoluteTimeGetCurrent();
    v = ceil( v / (60.*60.*24.) );
    if( v < 0 )
        return 0;
    return (int) v;
}

ActivationManager &ActivationManager::Instance()
{
    static auto inst = new ActivationManager;
    return *inst;
}

ActivationManager::ActivationManager()
{
    if( m_Type == Distribution::Paid ) {
        m_IsActivated = true;
    }
    else if( m_Type == Distribution::Trial ) {
        const bool has_mas_paid_version = UserHasPaidVersionInstalled();
        if(has_mas_paid_version)
            GoogleAnalytics::Instance().PostEvent("Licensing", "Activated Startup", "MAS Installed");
        const bool has_valid_license = UserHasValidAquaticLicense();
        if( has_valid_license ) {
            m_LicenseInfo = GetAquaticLicenseInfo( InstalledAquaticLicensePath() );
            GoogleAnalytics::Instance().PostEvent("Licensing", "Activated Startup", "License Installed");
        }
        
        m_UserHadRegistered = has_mas_paid_version || has_valid_license;
        m_IsActivated = true /*has_mas_paid_version || has_valid_license*/;
        
        if( !m_UserHadRegistered ) {
            if( !TrialStarted() )
                SetupTrialPeriod();

            m_TrialDaysLeft = ::TrialDaysLeft();
            
            if( m_TrialDaysLeft > 0 ) {
//                m_IsActivated = true;
                m_IsTrialPeriod = true;
                GoogleAnalytics::Instance().PostEvent("Licensing", "Trial Startup", "Trial valid", m_TrialDaysLeft);
            }
            else {
                GoogleAnalytics::Instance().PostEvent("Licensing", "Trial Startup", "Trial exceeded", -m_TrialDaysLeft);
                m_IsTrialPeriod = false;
            }
        }
    }
    else { // m_Type == Distribution::Free
        m_IsActivated = AppStoreReceiptContainsProFeaturesInApp();
    }
}

const string& ActivationManager::BundleID()
{
    static const string bundle_id = []{
        if( CFStringRef bundle_id = CFBundleGetIdentifier(CFBundleGetMainBundle()) )
            return CFStringGetUTF8StdString(bundle_id);
        else
            return "unknown"s;
    }();
    
    return bundle_id;
}

const string& ActivationManager::AppStoreID() const
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

bool ActivationManager::IsTrialPeriod() const noexcept
{
    return m_IsTrialPeriod;
}

int ActivationManager::TrialDaysLeft() const noexcept
{
    return m_TrialDaysLeft;
}

const string &ActivationManager::LicenseFileExtension() noexcept
{
    return g_LicenseExtension;
}

static bool CopyLicenseFile( const string& _source_path, const string &_dest_path )
{
    if( _source_path == _dest_path )
        return false;
    
    VFSFilePtr source;
    auto host = VFSNativeHost::SharedHost();
    if( host->CreateFile(_source_path.c_str(), source, nullptr) != VFSError::Ok )
        return false;
    
    if( source->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock) != VFSError::Ok )
        return false;
    
    auto data = source->ReadFile();
    if( !data )
        return false;
    
    source->Close();
    
    VFSFilePtr destination;
    if( host->CreateFile(_dest_path.c_str(), destination, nullptr) != VFSError::Ok )
        return false;
    
    using namespace VFSFlags;
    if( destination->Open(OF_Create | OF_Write | OF_Truncate | OF_IWUsr | OF_IRUsr) != VFSError::Ok )
        return false;
    
    if( destination->WriteFile(data->data(), data->size()) != VFSError::Ok )
        return false;
    
    return true;
}

bool ActivationManager::ProcessLicenseFile( const string& _path )
{
    if( Type() != ActivationManager::Distribution::Trial )
        return false;
        
    if( !CheckAquaticLicense(_path) )
        return false;
    
    if( !CopyLicenseFile( _path, InstalledAquaticLicensePath() ) )
        return false;
    
    m_UserHadRegistered = true;
    
    return true;;
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

const unordered_map<string, string> &ActivationManager::LicenseInformation() const noexcept
{
    return m_LicenseInfo;
}
