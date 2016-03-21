#include <AquaticPrime/AquaticPrime.h>
#include "MASAppInstalledChecker.h"
#include "AppDelegateCPP.h"
#include "ActivationManager.h"

static const char *g_LicenseFilename = "registration.nimblecommanderlicence";

static bool UserHasPaidVersionInstalled()
{
    string app_name = "Files Pro.app";
    string app_id   = "info.filesmanager.Files-Pro";
    return MASAppInstalledChecker::Instance().Has(app_name, app_id);
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

static bool UserHasValidAquaticLicense()
{
    return CheckAquaticLicense( AppDelegateCPP::SupportDirectory() + g_LicenseFilename );
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
        bool has_mas_paid_version = UserHasPaidVersionInstalled();
        bool has_valid_license = UserHasValidAquaticLicense();
        m_IsActivated = has_mas_paid_version || has_valid_license;
        cout << m_IsActivated << endl;
        
//        g_LicenseFilename
        
//        bool valid_key = CheckAquaticLicense( "/Users/migun/Library/Application Support/Nimble Commander/license.nimblecommanderkey" );
//        cout << CheckAquaticLicense( "/Users/migun/Library/Application Support/Nimble Commander/license.nimblecommanderkey" ) << endl;
//        cout << CheckAquaticLicense( "/Users/migun/Library/Application Support/Nimble Commander/license.nimblecommanderkey" ) << endl;
        
    }
    else { // m_Type == Distribution::Free
        // TODO: in-app purchase support
    }
    
    
}

const string& ActivationManager::BundleID() const
{
    return m_BundleID;
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
