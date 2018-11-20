// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "ActivationManager.h"
#include <VFS/Native.h>
#include <Habanero/CFDefaultsCPP.h>

// TODO: move this from XCTest to Catch2

using ExternalLicenseSupport = nc::bootstrap::ActivationManagerBase::ExternalLicenseSupport;
using TrialPeriodSupport = nc::bootstrap::ActivationManagerBase::TrialPeriodSupport;

static const auto g_TestPublicKey = 
"0xBA14D0390842EA0FCFCDED81EA64456F2B6C255241B1FF6E46E303823824B1E0C28F4031330EB03E1DAA7C1E2620A7BF"
"9524C13D52E69E1F730FBBDB70A75B485D6CF19461F5703919A7D51A559BC42708C364C9C0E9F61F00BB2AA4ABFFB57A5E"
"DE047DE7A87C4CB35218037265865C24D87A164815630390EFC5044F538981";

static const auto g_ValidLicense = 
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
"<plist version=\"1.0\">\n"
"<dict>\n"
"	<key>Email</key>\n"
"	<string>TestUser@email.com</string>\n"
"	<key>Name</key>\n"
"	<string>Test User</string>\n"
"	<key>Order</key>\n"
"	<string>XYZ171125-9876-12345</string>\n"
"	<key>Product</key>\n"
"	<string>Nimble Commander single-user license</string>\n"
"	<key>Signature</key>\n"
"	<data>\n"
"	lzPZyZFuiGTRZfL+CSDG7IvyGy1IxGX9xQglXKLX/G9L+8h9IPCvjpuFH3iVcGwrdbh4\n"
"	67dQMlSnymAd+EJazVPcGzvadmSTh1X9IG/CqektxPcaLeg/eF+Mosclm3FKwgTclLjh\n"
"	GWiwekLz9jU3CyDFyo1+9h3CkKavBmUO/9s=\n"
"	</data>\n"
"	<key>Timestamp</key>\n"
"	<string>Tue, 20 Nov 2018 12:37:19 +0700</string>\n"
"</dict>\n"
"</plist>";

static const auto g_LicenseWithBrokenSignature = 
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
"<plist version=\"1.0\">\n"
"<dict>\n"
"    <key>Email</key>\n"
"    <string>TestUser@email.com</string>\n"
"    <key>Name</key>\n"
"    <string>Test User</string>\n"
"    <key>Order</key>\n"
"    <string>XYZ171125-9876-12345</string>\n"
"    <key>Product</key>\n"
"    <string>Nimble Commander single-user license</string>\n"
"    <key>Signature</key>\n"
"    <data>\n"
"    lzPZyZFuiGTRZfL+CSDG8IvyGy1IxGX9xQglXKLX/G9L+8h9IPCvjpuFH3iVcGwrdbh4\n"
"    67dQMlSnymAd+EGaVsPcGzvadmSTh1X9IG/CqektxPcaLeg/eF+Mosclm3FKwgTclLjh\n"
"    GWiwekLz9jU3CyDFyo1+9h3CkKavBmUO/9s=\n"
"    </data>\n"
"    <key>Timestamp</key>\n"
"    <string>Tue, 20 Nov 2018 12:37:19 +0700</string>\n"
"</dict>\n"
"</plist>";

static const auto g_LicenseWithBrokenStructure = 
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
"<plist version=\"1.0\">\n"
"<dict>\n"
"	<key>Email</key>\n"
"	<string>TestUser@email.com</string"
"	<key>Name</key>\n"
"	<string>Test User</string>\n"
"	<key>Order</key>\n"
"	<string>XYZ171125-9876-12345</string>\n"
"	<key>Product</key>\n"
"	<string>Nimble Commander single-user license</string>\n"
"	<key>Signature</key>\n"
"	<data>\n"
"	lzPZyZFuiGTRZfL+CSDG7IvyGy1IxGX9xQglXKLX/G9L+8h9IPCvjpuFH3iVcGwrdbh4\n"
"	67dQMlSnymAd+EJazVPcGzvadmSTh1X9IG/CqektxPcaLeg/eF+Mosclm3FKwgTclLjh\n"
"	GWiwekLz9jU3CyDFyo1+9h3CkKavBmUO/9s=\n"
"	</data>\n"
"	<key>Timestamp</key>\n"
"	<string>Tue, 20 Nov 2018 12:37:19 +0700</string>\n"
"</dict>\n"
"</plist>";

static const auto g_LicenseWithEmptyPList = 
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
"<plist version=\"1.0\">\n"
"<dict>\n"
"</dict>\n"
"</plist>";

static const auto g_EmptyLicense = "";

static const auto g_DefaultsTrialExpireDate = CFSTR("__Test____TrialExpirationDate");

static std::optional<std::string> Load(const std::string &_filepath);
static bool Save(const std::string &_filepath, const std::string &_content);
static std::string MakeTmpDir();

@interface ActivationManager_ExternalLicenseSupport_Tests : XCTestCase
@end

@implementation ActivationManager_ExternalLicenseSupport_Tests
{
    std::string m_TmpDir;
    std::string m_InstalledLicensePath;
    std::unique_ptr<ExternalLicenseSupport> m_SUT;
}

- (void) setUp
{
    [super setUp];
    m_TmpDir = MakeTmpDir();
    m_InstalledLicensePath = m_TmpDir + "registration.nimblecommanderlicense";
    m_SUT = std::make_unique<ExternalLicenseSupport>(g_TestPublicKey, m_InstalledLicensePath);
}

- (void)tearDown
{
    VFSEasyDelete(m_TmpDir.c_str(), VFSNativeHost::SharedHost());
    [super tearDown];
}

- (void)testAcceptsAValidLicense
{
    const auto valid = m_SUT->CheckLicenseValidity(g_ValidLicense); 
    
    XCTAssert( valid == true );    
}

- (void)testDiscardsALicenseWithBrokenSignature
{
    const auto valid = m_SUT->CheckLicenseValidity(g_LicenseWithBrokenSignature); 
    
    XCTAssert( valid == false );    
}

- (void)testDiscardsALicenseWithBrokenStructure
{
    auto support = ExternalLicenseSupport{g_TestPublicKey, ""};
    
    const auto valid = m_SUT->CheckLicenseValidity(g_LicenseWithBrokenStructure); 
    
    XCTAssert( valid == false );    
}

- (void)testDiscardsALicenseWithEmptyPList
{
    const auto valid = m_SUT->CheckLicenseValidity(g_LicenseWithEmptyPList); 
    
    XCTAssert( valid == false );    
}

- (void)testDiscardsAnEmptyLicense
{
    const auto valid = m_SUT->CheckLicenseValidity(g_EmptyLicense); 
    
    XCTAssert( valid == false );    
}

- (void)testExtractsLisenceInfo
{
    auto info = m_SUT->ExtractLicenseInfo(g_ValidLicense);
    
    XCTAssert( info["Email"] == "TestUser@email.com" );
    XCTAssert( info["Name"] == "Test User" );
    XCTAssert( info["Order"] == "XYZ171125-9876-12345" );
    XCTAssert( info["Product"] == "Nimble Commander single-user license" );
    XCTAssert( info["Timestamp"] == "Tue, 20 Nov 2018 12:37:19 +0700" );
}

- (void)testReportsNoValidLicenseWhenNoneIsInstalled
{
    XCTAssert( m_SUT->HasValidInstalledLicense() == false );
}

- (void)testReportsHasAValidLicenseWhenOneIsInstalled
{
    Save(m_InstalledLicensePath, g_ValidLicense);
    XCTAssert( m_SUT->HasValidInstalledLicense() == true );
}

- (void)testReportsDoesntHaveAValidLicenseWhenInvalidIsInstalled
{
    Save(m_InstalledLicensePath, g_LicenseWithBrokenSignature);
    XCTAssert( m_SUT->HasValidInstalledLicense() == false );
}

- (void)testProperlyInstallsALicenseFile
{
    m_SUT->InstallNewLicenseWithData(g_ValidLicense);
    XCTAssert( m_SUT->HasValidInstalledLicense() == true );
    XCTAssert( *Load(m_InstalledLicensePath) == g_ValidLicense );
}

- (void)testExtractingInfoFromInstalledFileIsEqualToExtractingItFromTheData
{
    m_SUT->InstallNewLicenseWithData(g_ValidLicense);    
    const auto info_1 = m_SUT->ExtractInfoFromInstalledLicense(); 
    const auto info_2 = m_SUT->ExtractLicenseInfo(g_ValidLicense);
    XCTAssert( info_1 == info_2 );
}

- (void)testHandlesWriteErrors
{
    auto sut = ExternalLicenseSupport{g_TestPublicKey,
        "/some/nonexistentgibberish/path/registration.nimblecommanderlicense"};    
    
    XCTAssert( sut.InstallNewLicenseWithData(g_ValidLicense) == false );
}

@end

namespace {

class TrialPeriodSupportWithFakeTime : public TrialPeriodSupport
{
public:
    TrialPeriodSupportWithFakeTime(CFStringRef _defaults_trial_expire_date_key):
        TrialPeriodSupport(_defaults_trial_expire_date_key)
    {}
    
    double SecondsSinceMacEpoch() const override
    {
        return m_Time;
    }
    
    double m_Time = 0.;
};
    
}

@interface ActivationManager_TrialPeriodSupport_Tests : XCTestCase
@end

@implementation ActivationManager_TrialPeriodSupport_Tests
{
    std::unique_ptr<TrialPeriodSupportWithFakeTime> m_SUT;     
}

static double Y2015()
{    
    return 15. * 365. * 24. * 60. * 60.;
}

static double Y2018()
{    
    return 18. * 365. * 24. * 60. * 60.;
}

- (void) setUp
{
    [super setUp];
    CFDefaultsRemoveValue( g_DefaultsTrialExpireDate );
    m_SUT = std::make_unique<TrialPeriodSupportWithFakeTime>( g_DefaultsTrialExpireDate );
}

- (void)tearDown
{
    CFDefaultsRemoveValue( g_DefaultsTrialExpireDate );
    [super tearDown];
}

- (void) testTrialPeriodIsNotSetByDefault
{
    XCTAssert( m_SUT->IsTrialStarted() == false );
}

- (void) testReportsZeroLeftTrialDatsWhenTrialIsNotStarted
{
    XCTAssert( m_SUT->TrialDaysLeft() == 0 );
}

- (void) testDoesntCountTimestampsBefore2016AsTrialStarted
{
    CFDefaultsSetDouble( g_DefaultsTrialExpireDate, Y2015() );    
    XCTAssert( m_SUT->IsTrialStarted() == false );
}

- (void) testReportsTrialIsStartedWhenAValidTimespampIsPresent
{
    CFDefaultsSetDouble( g_DefaultsTrialExpireDate, Y2018() );    
    XCTAssert( m_SUT->IsTrialStarted() == true );
}

- (void) testSettingTrialPeriodSetsTimePointOnExpiraion
{
    auto _30_days = 30. * 24. * 60. * 60.;
    m_SUT->m_Time = Y2018();
    m_SUT->SetupTrialPeriod(_30_days);
    XCTAssertEqualWithAccuracy(CFDefaultsGetDouble(g_DefaultsTrialExpireDate), 
                               Y2018() + _30_days,
                               1.);
}

- (void) testTrialPeriodIsStartedAfterSettingUp
{
    auto _30_days = 30. * 24. * 60. * 60.;
    m_SUT->m_Time = Y2018();
    m_SUT->SetupTrialPeriod(_30_days);
    XCTAssert( m_SUT->IsTrialStarted() == true );
    XCTAssert( m_SUT->TrialDaysLeft() == 30 );
}

- (void) testReportsExpiredTrialsAsZeroLeftDays
{
    auto _30_days = 30. * 24. * 60. * 60.;
    m_SUT->m_Time = Y2018();
    m_SUT->SetupTrialPeriod(_30_days);
    
    m_SUT->m_Time += _30_days;
    XCTAssert( m_SUT->TrialDaysLeft() == 0 );
    
    m_SUT->m_Time += _30_days;
    XCTAssert( m_SUT->TrialDaysLeft() == 0 );
}

- (void) testDeletingTrialPeriodInfoRemovesTheEntryInDefaults
{
    auto _30_days = 30. * 24. * 60. * 60.;
    m_SUT->m_Time = Y2018();
    m_SUT->SetupTrialPeriod(_30_days);

    m_SUT->DeleteTrialPeriodInfo();
    
    XCTAssert( CFDefaultsHasValue(g_DefaultsTrialExpireDate) == false );
}

- (void) testNonFakedImplementationUsesSystemTime
{
    auto sut = TrialPeriodSupport{g_DefaultsTrialExpireDate};
    auto _30_days = 30. * 24. * 60. * 60.;
    sut.SetupTrialPeriod(_30_days);
    XCTAssertEqualWithAccuracy(CFDefaultsGetDouble(g_DefaultsTrialExpireDate), 
                               CFAbsoluteTimeGetCurrent() + _30_days,
                               1.);
}

@end

@interface ActivationManager_Tests : XCTestCase
@end

@implementation ActivationManager_Tests
{
    std::string m_TmpDir;
    std::string m_InstalledLicensePath;
    std::string m_TempLicensePath;
}

- (void) setUp
{
    [super setUp];
    m_TmpDir = MakeTmpDir();
    m_InstalledLicensePath = m_TmpDir + "registration.nimblecommanderlicense";
    m_TempLicensePath = m_TmpDir + "test.nimblecommanderlicense";
}

- (void)tearDown
{
    VFSEasyDelete(m_TmpDir.c_str(), VFSNativeHost::SharedHost());
    [super tearDown];
}

@end

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

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out( _filepath, std::ios::out | std::ios::binary );
    if( !out )
        return false;        
    out << _content;    
    out.close();
    return true;        
}

static std::string MakeTmpDir()
{
    char dir[MAXPATHLEN];
    sprintf(dir,
            "%s" "info.filesmanager.files" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    const auto res = mkdtemp(dir); 
    assert( res != nullptr );
    return string{dir} + "/";
}
