// Copyright (C) 2018-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
//#include <NimbleCommander/Bootstrap/ActivationManagerImpl.h>
#include <NimbleCommander/Bootstrap/ActivationManagerBase.h>
#include <VFS/Native.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/GoogleAnalytics.h>
#include <ftw.h>

using ExternalLicenseSupport = nc::bootstrap::ActivationManagerBase::ExternalLicenseSupport;
using TrialPeriodSupport = nc::bootstrap::ActivationManagerBase::TrialPeriodSupport;
//using nc::bootstrap::ActivationManagerImpl;

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

[[maybe_unused]] static const auto g_DefaultsTrialExpireDate = CFSTR("__Test____TrialExpirationDate");

static const double g_Y2015 = 15. * 365. * 24. * 60. * 60.;
static const double g_Y2018 = 18. * 365. * 24. * 60. * 60.;

static std::optional<std::string> Load(const std::string &_filepath);
static bool Save(const std::string &_filepath, const std::string &_content);

#define PREFIX "ActivationManagerBase::ExternalLicenseSupport "

struct ExternalLicenseSupportContext {
    TempTestDir tmpdir;
    std::string installed_license_path;
    ExternalLicenseSupport sut;

    ExternalLicenseSupportContext():
    installed_license_path( tmpdir.directory.native() + "registration.nimblecommanderlicense" ),
    sut(g_TestPublicKey, installed_license_path)
    {
    }
};

TEST_CASE(PREFIX"accepts a valid license")
{
    ExternalLicenseSupportContext ctx;
    CHECK( ctx.sut.CheckLicenseValidity(g_ValidLicense) );
}

TEST_CASE(PREFIX"discards a license with broken signature")
{
    ExternalLicenseSupportContext ctx;
    CHECK( ctx.sut.CheckLicenseValidity(g_LicenseWithBrokenSignature) == false );
}

TEST_CASE(PREFIX"discards a license with broken structure")
{
    ExternalLicenseSupportContext ctx;
    CHECK( ctx.sut.CheckLicenseValidity(g_LicenseWithBrokenStructure) == false );
}

TEST_CASE(PREFIX"discards a license with empty plist")
{
    // TODO: prints "No signature" - remove it
    ExternalLicenseSupportContext ctx;
    CHECK( ctx.sut.CheckLicenseValidity(g_LicenseWithEmptyPList) == false );
}

TEST_CASE(PREFIX"discards a empty license")
{
    ExternalLicenseSupportContext ctx;
    CHECK( ctx.sut.CheckLicenseValidity(g_EmptyLicense) == false );
}

TEST_CASE(PREFIX"extracts lisence info")
{
    ExternalLicenseSupportContext ctx;
    auto info = ctx.sut.ExtractLicenseInfo(g_ValidLicense);

    CHECK( info["Email"] == "TestUser@email.com" );
    CHECK( info["Name"] == "Test User" );
    CHECK( info["Order"] == "XYZ171125-9876-12345" );
    CHECK( info["Product"] == "Nimble Commander single-user license" );
    CHECK( info["Timestamp"] == "Tue, 20 Nov 2018 12:37:19 +0700" );
}

TEST_CASE(PREFIX"doesnt extract info from invalid license")
{
    ExternalLicenseSupportContext ctx;
    auto info = ctx.sut.ExtractLicenseInfo(g_LicenseWithBrokenSignature);
    CHECK( info.empty() == true );
}

TEST_CASE(PREFIX"reports no valid license when none is installed")
{
    ExternalLicenseSupportContext ctx;
    CHECK( ctx.sut.HasValidInstalledLicense() == false );
}

TEST_CASE(PREFIX"reports has a valid license when one is installed")
{
    ExternalLicenseSupportContext ctx;
    Save(ctx.installed_license_path, g_ValidLicense);
    CHECK( ctx.sut.HasValidInstalledLicense() == true );
}

TEST_CASE(PREFIX"properly installs a license file")
{
    ExternalLicenseSupportContext ctx;
    ctx.sut.InstallNewLicenseWithData(g_ValidLicense);
    REQUIRE( ctx.sut.HasValidInstalledLicense() == true );
    CHECK( *Load(ctx.installed_license_path) == g_ValidLicense );
}

TEST_CASE(PREFIX"extracting info from installed file is equal to extracting it from the data")
{
    ExternalLicenseSupportContext ctx;
    ctx.sut.InstallNewLicenseWithData(g_ValidLicense);
    const auto info_1 = ctx.sut.ExtractInfoFromInstalledLicense();
    const auto info_2 = ctx.sut.ExtractLicenseInfo(g_ValidLicense);
    CHECK( info_1 == info_2 );
}

TEST_CASE(PREFIX"handles write errors")
{
    auto sut = ExternalLicenseSupport{g_TestPublicKey,
        "/some/nonexistentgibberish/path/registration.nimblecommanderlicense"};

    CHECK( sut.InstallNewLicenseWithData(g_ValidLicense) == false );
}
#undef PREFIX
#define PREFIX "ActivationManagerBase::TrialPeriodSupport "

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

struct TrialPeriodSupportContext {
    int init = []{CFDefaultsRemoveValue( g_DefaultsTrialExpireDate ); return 0;}();
    TrialPeriodSupportWithFakeTime sut { g_DefaultsTrialExpireDate  };
    
    ~TrialPeriodSupportContext()
    {
        CFDefaultsRemoveValue( g_DefaultsTrialExpireDate );
    }
};

TEST_CASE(PREFIX"trial period is not set by default")
{
    TrialPeriodSupportContext ctx;
    CHECK( ctx.sut.IsTrialStarted() == false );
}

TEST_CASE(PREFIX"reports zero left trial days when trial is not started")
{
    TrialPeriodSupportContext ctx;
    CHECK( ctx.sut.TrialDaysLeft() == 0 );
}

TEST_CASE(PREFIX"doesnt count timestamps before 2016 as trial started")
{
    TrialPeriodSupportContext ctx;
    CFDefaultsSetDouble( g_DefaultsTrialExpireDate, g_Y2015 );
    CHECK( ctx.sut.IsTrialStarted() == false );
}

TEST_CASE(PREFIX"reports trial is started when a valid timespamp is present")
{
    TrialPeriodSupportContext ctx;
    CFDefaultsSetDouble( g_DefaultsTrialExpireDate, g_Y2018 );
    CHECK( ctx.sut.IsTrialStarted() == true );
}

TEST_CASE(PREFIX"setting trial period sets time point on expiraion")
{
    TrialPeriodSupportContext ctx;
    auto _30_days = 30. * 24. * 60. * 60.;
    ctx.sut.m_Time = g_Y2018;
    ctx.sut.SetupTrialPeriod(_30_days);
    CHECK( std::fabs( CFDefaultsGetDouble(g_DefaultsTrialExpireDate) - (g_Y2018 + _30_days)) <= 1. );
}

TEST_CASE(PREFIX"trial period is started after setting up")
{
    TrialPeriodSupportContext ctx;
    auto _30_days = 30. * 24. * 60. * 60.;
    ctx.sut.m_Time = g_Y2018;
    ctx.sut.SetupTrialPeriod(_30_days);
    CHECK( ctx.sut.IsTrialStarted() == true );
    CHECK( ctx.sut.TrialDaysLeft() == 30 );
}

TEST_CASE(PREFIX"reports expired trials as zero left days")
{
    TrialPeriodSupportContext ctx;
    auto _30_days = 30. * 24. * 60. * 60.;
    ctx.sut.m_Time = g_Y2018;
    ctx.sut.SetupTrialPeriod(_30_days);

    ctx.sut.m_Time += _30_days;
    CHECK( ctx.sut.TrialDaysLeft() == 0 );

    ctx.sut.m_Time += _30_days;
    CHECK( ctx.sut.TrialDaysLeft() == 0 );
}

TEST_CASE(PREFIX"deleting trial period info removes the entry in defaults")
{
    TrialPeriodSupportContext ctx;
    auto _30_days = 30. * 24. * 60. * 60.;
    ctx.sut.m_Time = g_Y2018;
    ctx.sut.SetupTrialPeriod(_30_days);

    ctx.sut.DeleteTrialPeriodInfo();

    CHECK( CFDefaultsHasValue(g_DefaultsTrialExpireDate) == false );
}

TEST_CASE(PREFIX "non faked implementation uses system time")
{
    auto sut = TrialPeriodSupport{g_DefaultsTrialExpireDate};
    auto _30_days = 30. * 24. * 60. * 60.;
    sut.SetupTrialPeriod(_30_days);
    CHECK(std::fabs(CFDefaultsGetDouble(g_DefaultsTrialExpireDate) -
                    (CFAbsoluteTimeGetCurrent() + _30_days)) <= 1.);
}

//@end
//
//@interface ActivationManager_Tests : XCTestCase
//@end
//
//@implementation ActivationManager_Tests
//{
//    std::string m_TmpDir;
//    std::string m_InstalledLicensePath;
//    std::string m_TempLicensePath;
//    std::unique_ptr<ExternalLicenseSupport> m_License;
//    std::unique_ptr<TrialPeriodSupportWithFakeTime> m_Trial;
//    std::unique_ptr<GoogleAnalytics> m_GA;
//}
//
//- (void) setUp
//{
//    [super setUp];
//    m_TmpDir = MakeTmpDir();
//    CFDefaultsRemoveValue( g_DefaultsTrialExpireDate );
//    m_InstalledLicensePath = m_TmpDir + "registration.nimblecommanderlicense";
//    m_TempLicensePath = m_TmpDir + "test.nimblecommanderlicense";
//    m_License = std::make_unique<ExternalLicenseSupport>(g_TestPublicKey, m_InstalledLicensePath);
//    m_Trial = std::make_unique<TrialPeriodSupportWithFakeTime>( g_DefaultsTrialExpireDate );
//    m_Trial->m_Time = Y2018();
//    m_GA = std::make_unique<GoogleAnalytics>();
//}
//
//- (void)tearDown
//{
//    RMRF(m_TmpDir);
//    CFDefaultsRemoveValue( g_DefaultsTrialExpireDate );
//    [super tearDown];
//}
//
//- (void)testIsCheckingTrialBuild
//{
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    XCTAssert( sut.Type() == ActivationManager::Distribution::Trial );
//    XCTAssert( sut.Sandboxed() == false );
//}
//
//- (void)testByDefaultUsesDidntRegister
//{
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    // this can be an environment side effect not being DIed at the moment
//    XCTAssert( sut.UserHasProVersionInstalled() == false );
//}
//
//- (void)testByDefaultStartsTrialPeriod
//{
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//
//    XCTAssert( m_Trial->IsTrialStarted() == true );
//    XCTAssert( sut.IsTrialPeriod() == true );
//    XCTAssert( sut.TrialDaysLeft() == 30 );
//}
//
//- (void)testDoesntOverwriteExistingTrialPeriod
//{
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    }
//    const auto time_stamp_before = CFDefaultsGetDouble(g_DefaultsTrialExpireDate);
//    m_Trial->m_Time += 1. * 24. * 60. * 60.;
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    }
//    const auto time_stamp_after = CFDefaultsGetDouble(g_DefaultsTrialExpireDate);
//    XCTAssert( time_stamp_before == time_stamp_after );
//}
//
//- (void)testByDefaultShouldntShowNagScreen
//{
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//
//    XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//}
//
//- (void)testReportsUserHadRegisteredWhenAValidLicenseFileIsInstalled
//{
//    Save(m_InstalledLicensePath, g_ValidLicense);
//
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//
//    XCTAssert( sut.UserHadRegistered() == true );
//    XCTAssert( sut.IsTrialPeriod() == false );
//    XCTAssert( sut.TrialDaysLeft() == 0 );
//}
//
//- (void)testIgnoresAnInvalidInstalledLicense
//{
//    Save(m_InstalledLicensePath, g_LicenseWithBrokenSignature);
//
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//
//    XCTAssert( m_Trial->IsTrialStarted() == true );
//    XCTAssert( sut.IsTrialPeriod() == true );
//    XCTAssert( sut.TrialDaysLeft() == 30 );
//}
//
//- (void)testShowsNagScreenWhenLessThan15DaysIsLeft
//{
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//
//    {
//        m_Trial->m_Time += 14. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//
//    {
//        m_Trial->m_Time += 1. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == true );
//    }
//
//    {
//        m_Trial->m_Time += 1. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == true );
//    }
//}
//
//- (void)testDontShowNagScreenWhenLicenseFileIsInstalled
//{
//    Save(m_InstalledLicensePath, g_ValidLicense);
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//    {
//        m_Trial->m_Time += 100. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//}
//
//- (void)testDontShowNagScreenWhenLicenseFileIsInstalledAndTrialIsExpired
//{
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//    {
//        m_Trial->m_Time += 20 * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == true );
//    }
//    Save(m_InstalledLicensePath, g_ValidLicense);
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//    {
//        m_Trial->m_Time += 100. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.ShouldShowTrialNagScreen() == false );
//    }
//}
//
//- (void)testFinishesTrialPeriodAfter30Days
//{
//    {
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.UserHadRegistered() == false );
//        XCTAssert( sut.IsTrialPeriod() == true );
//        XCTAssert( sut.TrialDaysLeft() == 30 );
//    }
//
//    {
//        m_Trial->m_Time += 14. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.UserHadRegistered() == false );
//        XCTAssert( sut.IsTrialPeriod() == true );
//        XCTAssert( sut.TrialDaysLeft() == 16 );
//    }
//
//    {
//        m_Trial->m_Time += 15. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.UserHadRegistered() == false );
//        XCTAssert( sut.IsTrialPeriod() == true );
//        XCTAssert( sut.TrialDaysLeft() == 1 );
//    }
//
//    {
//        m_Trial->m_Time += 1. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.UserHadRegistered() == false );
//        XCTAssert( sut.IsTrialPeriod() == false );
//        XCTAssert( sut.TrialDaysLeft() == 0 );
//    }
//
//    {
//        m_Trial->m_Time += 5. * 24. * 60. * 60.;
//        auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//        XCTAssert( sut.UserHadRegistered() == false );
//        XCTAssert( sut.IsTrialPeriod() == false );
//        XCTAssert( sut.TrialDaysLeft() == 0 );
//    }
//}
//
//- (void)testByDefaultReportsAnEmptyLicenseInfo
//{
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    XCTAssert( sut.LicenseInformation().empty() == true );
//}
//
//- (void)testReportsProperInfoWhenLicenseFileIsInstalled
//{
//    Save(m_InstalledLicensePath, g_ValidLicense);
//
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    auto info = sut.LicenseInformation();
//    XCTAssert( info["Name"] == "Test User" );
//}
//
//- (void)testAfterProcessingAValidLicenseFileTheUserIsRegistered
//{
//    Save(m_TempLicensePath, g_ValidLicense);
//
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile(m_TempLicensePath) == true );
//    XCTAssert( sut.UserHadRegistered() == true );
//
//    auto info = sut.LicenseInformation();
//    XCTAssert( info["Name"] == "Test User" );
//}
//
//- (void)testIgnoresProcessingInvalidLicenseFile
//{
//    Save(m_TempLicensePath, g_LicenseWithBrokenSignature);
//
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile(m_TempLicensePath) == false );
//    XCTAssert( sut.UserHadRegistered() == false );
//}
//
//- (void)testIgnoresProcessingInvalidLicenseFilePath
//{
//    auto sut = ActivationManager{*m_License, *m_Trial, *m_GA};
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile("/some/abra/cadabra/alakazam/aaa.txt") == false );
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile("/Applications/") == false );
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile("/private/var/root/.forward") == false );
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile("odufhpshfpsdhfhusdf!@#$%^&*()±_+-=") == false );
//    XCTAssert( sut.UserHadRegistered() == false );
//
//    XCTAssert( sut.ProcessLicenseFile("") == false );
//    XCTAssert( sut.UserHadRegistered() == false );
//}
//
//- (void)testReportsProperLicenseFileExtension
//{
//    XCTAssert( ActivationManager::LicenseFileExtension() == "nimblecommanderlicense" );
//}
//
//@end
//
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
//
//static std::string MakeTmpDir()
//{
//    char dir[MAXPATHLEN];
//    sprintf(dir,
//            "%s" "info.filesmanager.files" ".tmp.XXXXXX",
//            NSTemporaryDirectory().fileSystemRepresentation);
//    const auto res = mkdtemp(dir);
//    assert( res != nullptr );
//    return std::string{dir} + "/";
//}
//
//static int RMRF(const std::string& _path)
//{
//    auto unlink_cb = [](const char *fpath,
//                        [[maybe_unused]] const struct stat *sb,
//                        int typeflag,
//                        [[maybe_unused]] struct FTW *ftwbuf) {
//        if( typeflag == FTW_F)
//            unlink(fpath);
//        else if( typeflag == FTW_D   ||
//                typeflag == FTW_DNR ||
//                typeflag == FTW_DP   )
//            rmdir(fpath);
//        return 0;
//    };
//    return nftw(_path.c_str(), unlink_cb, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
//}
