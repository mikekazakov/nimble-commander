#import <XCTest/XCTest.h>
#include <thread>
#include "../include/Operations/Operation.h"
#include "../include/Operations/Job.h"

using namespace std;

#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <VFS/Native.h>

static const std::string g_Preffix = "/.FilesTestingData/archives/";
static const std::string g_Adium = g_Preffix + "adium.app.zip";


using namespace nc::ops;

namespace {


struct MyJob : public Job
{
    virtual void Perform()
    {
        std::this_thread::sleep_for( std::chrono::milliseconds{500} );
        SetCompleted();
    }
};

struct MyOperation : public Operation
{
    ~MyOperation()
    {
        Wait();
    }
    virtual Job *GetJob() noexcept { return &job; }
    MyJob job;
};

}

@interface BasicOperationsSemanticsTests : XCTestCase

@end

@implementation BasicOperationsSemanticsTests


- (void)testExternalWait
{
    MyOperation myop;
    
    std::mutex cv_lock;
    std::condition_variable cv;
    
//    myop.SetFinishCallback([&]{ cv.notify_all(); });
    myop.ObserveUnticketed(Operation::NotifyAboutFinish, [&]{ cv.notify_all(); });    
    
    myop.Start();
    XCTAssert( myop.State() == OperationState::Running );

    std::unique_lock<std::mutex> lock{cv_lock};
    cv.wait(lock, [&]{ return myop.State() >= OperationState::Stopped; });

    XCTAssert( myop.State() == OperationState::Completed );
}

- (void)testBuiltinWait
{
    MyOperation myop;
    myop.Start();
    myop.Wait();
    XCTAssert( myop.State() == OperationState::Completed );
}

- (void)testBuiltinPartialWait
{
    MyOperation myop;
    myop.Start();
    XCTAssert( myop.Wait( std::chrono::milliseconds{200} ) == false );
    XCTAssert( myop.State() == OperationState::Running );
}

- (void)testAccidentalOperationWait
{
    MyOperation myop;
    myop.Start();
    XCTAssert( myop.State() == OperationState::Running );
}

- (void)testNonStartedOperationBehaviour
{
    MyOperation myop;
    XCTAssert( myop.State() == OperationState::Cold );
}

//- (void)testAdiumZip_CopyFromVFS
//{
////    auto dir = self.makeTmpDir;
//    
//    std::shared_ptr<VFSArchiveHost> host;
//    try {
//        host = std::make_shared<VFSArchiveHost>(g_Adium.c_str(), VFSNativeHost::SharedHost());
//    } catch (VFSErrorException &e) {
//        XCTAssert( e.code() == 0 );
//        return;
//    }
//}

@end

