// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "DiskUtility.h"
#include "ObjCpp.h"

using namespace nc::utility;


static NSDictionary *DictionaryFromPListString(std::string_view _str);

extern const std::string_view g_APFSListExample;

// This not really a unit test - it's an integration test and it should be moved to 
// another test suite later.
TEST_CASE("DiskUtility::ListAPFSObjects returns a valid nonempty NSDictionary tree")
{
    DiskUtility du;
    const auto dict = du.ListAPFSObjects();
    REQUIRE( dict != nil );
    REQUIRE( dict[@"Containers"] != nil );
    REQUIRE( objc_cast<NSArray>(dict[@"Containers"]) != nil );
}

TEST_CASE("APFSTree can find a container name from its volume")
{
    APFSTree tree{DictionaryFromPListString(g_APFSListExample)};
    
    CHECK( tree.FindContainerOfVolume("disk1s1") == "disk1" );
    CHECK( tree.FindContainerOfVolume("disk1s2") == "disk1" );
    CHECK( tree.FindContainerOfVolume("disk1s3") == "disk1" );
    CHECK( tree.FindContainerOfVolume("disk1s4") == "disk1" );
    CHECK( tree.FindContainerOfVolume("disk4s1") == "disk4" );
    CHECK( tree.FindContainerOfVolume("disk4s2") == "disk4" );
    CHECK( tree.FindContainerOfVolume("disk4s3") == "disk4" );
    CHECK( tree.FindContainerOfVolume("disk4s4") == "disk4" );
    CHECK( tree.FindContainerOfVolume("disk6s1") == "disk6" );
    CHECK( tree.FindContainerOfVolume("disk5s1") == std::nullopt );
    CHECK( tree.FindContainerOfVolume("") == std::nullopt );
    CHECK( tree.FindContainerOfVolume("ushdfisuhfoihsdf") == std::nullopt );    
}

TEST_CASE("APFSTree can find volumes from their container name")
{
    APFSTree tree{DictionaryFromPListString(g_APFSListExample)};

    const auto disk1_volumes = std::vector<std::string>{"disk1s1", "disk1s2", "disk1s3", "disk1s4"};
    CHECK( tree.FindVolumesOfContainer("disk1") == disk1_volumes );
    
    const auto disk4_volumes = std::vector<std::string>{"disk4s2", "disk4s3", "disk4s4", "disk4s1"};
    CHECK( tree.FindVolumesOfContainer("disk4") == disk4_volumes );
    
    const auto disk6_volumes = std::vector<std::string>{"disk6s1"};
    CHECK( tree.FindVolumesOfContainer("disk6") == disk6_volumes );

    CHECK( tree.FindVolumesOfContainer("disk2") == std::nullopt );
    CHECK( tree.FindVolumesOfContainer("") == std::nullopt );
    CHECK( tree.FindVolumesOfContainer("piuoivuhovhs") == std::nullopt );    
}

TEST_CASE("APFSTree can find physical stores from a container name")
{
    APFSTree tree{DictionaryFromPListString(g_APFSListExample)};

    const auto disk1_stores = std::vector<std::string>{"disk0s2"};
    CHECK( tree.FindPhysicalStoresOfContainer("disk1") == disk1_stores );

    const auto disk4_stores = std::vector<std::string>{"disk3s2"};
    CHECK( tree.FindPhysicalStoresOfContainer("disk4") == disk4_stores );

    const auto disk6_stores = std::vector<std::string>{"disk5s1"};
    CHECK( tree.FindPhysicalStoresOfContainer("disk6") == disk6_stores );
    
    CHECK( tree.FindPhysicalStoresOfContainer("disk2") == std::nullopt );
    CHECK( tree.FindPhysicalStoresOfContainer("") == std::nullopt );
    CHECK( tree.FindPhysicalStoresOfContainer("piuoivuhovhs") == std::nullopt );      
}

static NSDictionary *DictionaryFromPListString(std::string_view _str)
{
    const auto data = [[NSData alloc] initWithBytesNoCopy:(void*)_str.data()
                                                   length:_str.length()
                                             freeWhenDone:false];
    
    const id root = [NSPropertyListSerialization propertyListWithData:data
                                                              options:NSPropertyListImmutable
                                                               format:nil
                                                                error:nil];
    
    return objc_cast<NSDictionary>(root);
}

const std::string_view g_APFSListExample = 
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
"<plist version=\"1.0\">"
"<dict>"
"	<key>Containers</key>"
"	<array>"
"		<dict>"
"			<key>APFSContainerUUID</key>"
"			<string>205816A4-BF3B-4A3F-9BEE-6339732D74D9</string>"
"			<key>CapacityCeiling</key>"
"			<integer>489999998976</integer>"
"			<key>CapacityFree</key>"
"			<integer>87074734080</integer>"
"			<key>ContainerReference</key>"
"			<string>disk1</string>"
"			<key>DesignatedPhysicalStore</key>"
"			<string>disk0s2</string>"
"			<key>Fusion</key>"
"			<false/>"
"			<key>PhysicalStores</key>"
"			<array>"
"				<dict>"
"					<key>DeviceIdentifier</key>"
"					<string>disk0s2</string>"
"					<key>DiskUUID</key>"
"					<string>CD1BA3FD-15DC-48CA-A86D-4A897C893821</string>"
"					<key>Size</key>"
"					<integer>489999998976</integer>"
"				</dict>"
"			</array>"
"			<key>Volumes</key>"
"			<array>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>56D7EFCC-0CFF-4B80-BD97-3FD1BA491A13</string>"
"					<key>CapacityInUse</key>"
"					<integer>397379031040</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk1s1</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>Macintosh HD</string>"
"					<key>Roles</key>"
"					<array/>"
"				</dict>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>AB4F7830-BD63-4B5C-AE16-6ABE72838990</string>"
"					<key>CapacityInUse</key>"
"					<integer>61190144</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk1s2</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>Preboot</string>"
"					<key>Roles</key>"
"					<array>"
"						<string>Preboot</string>"
"					</array>"
"				</dict>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>8FB26E3E-152A-43C7-9CEF-E2F2C38D42C8</string>"
"					<key>CapacityInUse</key>"
"					<integer>1029431296</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk1s3</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>Recovery</string>"
"					<key>Roles</key>"
"					<array>"
"						<string>Recovery</string>"
"					</array>"
"				</dict>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>BA8E0ABA-F66D-4444-A011-028F360D50F8</string>"
"					<key>CapacityInUse</key>"
"					<integer>4295012352</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk1s4</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>VM</string>"
"					<key>Roles</key>"
"					<array>"
"						<string>VM</string>"
"					</array>"
"				</dict>"
"			</array>"
"		</dict>"
"		<dict>"
"			<key>APFSContainerUUID</key>"
"			<string>CC8D156F-D41B-4E46-857D-6456D1B21B3C</string>"
"			<key>CapacityCeiling</key>"
"			<integer>239847653376</integer>"
"			<key>CapacityFree</key>"
"			<integer>144667172864</integer>"
"			<key>ContainerReference</key>"
"			<string>disk4</string>"
"			<key>DesignatedPhysicalStore</key>"
"			<string>disk3s2</string>"
"			<key>Fusion</key>"
"			<false/>"
"			<key>PhysicalStores</key>"
"			<array>"
"				<dict>"
"					<key>DeviceIdentifier</key>"
"					<string>disk3s2</string>"
"					<key>DiskUUID</key>"
"					<string>D8F19B78-BB34-416F-85D7-A118E33CF110</string>"
"					<key>Size</key>"
"					<integer>239847653376</integer>"
"				</dict>"
"			</array>"
"			<key>Volumes</key>"
"			<array>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>98F22672-FFCD-4C2E-B0A4-EB045616328E</string>"
"					<key>CapacityInUse</key>"
"					<integer>20480</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk4s2</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>Preboot</string>"
"					<key>Roles</key>"
"					<array>"
"						<string>Preboot</string>"
"					</array>"
"				</dict>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>2134DB37-02F8-428B-BC46-F36E4CFDF5A0</string>"
"					<key>CapacityInUse</key>"
"					<integer>20480</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk4s3</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>Recovery</string>"
"					<key>Roles</key>"
"					<array>"
"						<string>Recovery</string>"
"					</array>"
"				</dict>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>6DC21348-428B-4E5A-AFD8-FD00500E5386</string>"
"					<key>CapacityInUse</key>"
"					<integer>3221245952</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk4s4</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>VM</string>"
"					<key>Roles</key>"
"					<array>"
"						<string>VM</string>"
"					</array>"
"				</dict>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>7713F3E8-BCFA-4B54-BFB6-5EECA21D344C</string>"
"					<key>CapacityInUse</key>"
"					<integer>91821821952</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk4s1</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>VMs</string>"
"					<key>Roles</key>"
"					<array/>"
"				</dict>"
"			</array>"
"		</dict>"
"		<dict>"
"			<key>APFSContainerUUID</key>"
"			<string>F1E09F8D-3268-4DBE-98F8-C09D151F49F6</string>"
"			<key>CapacityCeiling</key>"
"			<integer>99983360</integer>"
"			<key>CapacityFree</key>"
"			<integer>98811904</integer>"
"			<key>ContainerReference</key>"
"			<string>disk6</string>"
"			<key>DesignatedPhysicalStore</key>"
"			<string>disk5s1</string>"
"			<key>Fusion</key>"
"			<false/>"
"			<key>PhysicalStores</key>"
"			<array>"
"				<dict>"
"					<key>DeviceIdentifier</key>"
"					<string>disk5s1</string>"
"					<key>DiskUUID</key>"
"					<string>F5480BF5-DAFF-4240-9CCA-1CDFD894BBC7</string>"
"					<key>Size</key>"
"					<integer>99983360</integer>"
"				</dict>"
"			</array>"
"			<key>Volumes</key>"
"			<array>"
"				<dict>"
"					<key>APFSVolumeUUID</key>"
"					<string>64A90F43-77CF-40E0-97B9-A146FAFB4E22</string>"
"					<key>CapacityInUse</key>"
"					<integer>81920</integer>"
"					<key>CapacityQuota</key>"
"					<integer>0</integer>"
"					<key>CapacityReserve</key>"
"					<integer>0</integer>"
"					<key>CryptoMigrationOn</key>"
"					<false/>"
"					<key>DeviceIdentifier</key>"
"					<string>disk6s1</string>"
"					<key>Encryption</key>"
"					<false/>"
"					<key>FileVault</key>"
"					<false/>"
"					<key>Locked</key>"
"					<false/>"
"					<key>Name</key>"
"					<string>Untitled</string>"
"					<key>Roles</key>"
"					<array/>"
"				</dict>"
"			</array>"
"		</dict>"
"	</array>"
"</dict>"
"</plist>";
